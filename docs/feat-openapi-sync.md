# backend OpenAPI 스펙 드리프트 감지 명세서 (feat/openapi-sync)

## 1. 문서 목적

이 문서는 `feat/openapi-sync` 브랜치에서 진행한 backend OpenAPI 스펙 사본 도입과 CI 드리프트 검사 작업의 배경과 결정 내용을 정의한다.

## 2. 문제 상황

- backend API가 바뀌어도 frontend는 알 방법이 없었다. 수동 작성된 API 클라이언트(`lib/features/*/data/`)가 스펙과 어긋난 채 머지될 수 있었다.
- 개발 중 API 계약을 확인하려면 backend 리포나 Swagger UI를 따로 열어야 했다.

## 3. 변경 내용

### 스펙 사본 (`docs/openapi.json`)

backend 리포의 `docs/openapi.json`을 그대로 복사해 둔다. backend는 `OpenApiDocsTest`가 이 파일을 정본으로 강제하고(스펙 덤프를 키 정렬·들여쓰기로 정규화해 CI에서 diff), 애초에 "프론트 클라이언트 생성과 CI의 스펙 최신성 검사"를 목적으로 만든 파일이라 backend main의 파일은 항상 실제 코드와 일치한다.

- 검토한 대안 1: GHCR 이미지를 CI에서 기동해 `/v3/api-docs`를 긁기 — 수 분 소요, backend가 이미 파일 정본을 제공하므로 불필요해 제외.
- 검토한 대안 2: openapi-generator로 Dart 클라이언트 생성 — 수동 작성된 기존 클라이언트 전체를 대체하는 큰 전환이라 이번 범위에서 제외.
- 최종 결정: 사본 커밋 + CI 바이트 비교(드리프트 감지)만 도입.

### CI 드리프트 검사 (`.github/workflows/ci.yml`)

`openapi-drift` 잡을 추가했다. backend main의 raw `docs/openapi.json`을 curl로 받아 커밋된 사본과 `diff`로 비교하고, 다르면 실패시킨다. backend가 스펙을 정규화해 두므로 바이트 비교로 충분하다. 소요 시간은 수 초라 기존 `check` 잡과 병렬로 돌며 전체 CI 시간에 영향이 없다.

### 줄바꿈 보존 (`.gitattributes`)

`docs/openapi.json -text`를 추가했다. Windows 로컬(`core.autocrlf=true`)에서 체크아웃·재커밋 시 줄바꿈이 변환되면 backend 원본과 바이트가 어긋나 CI diff가 헛실패하므로, 이 파일은 git의 텍스트 변환에서 제외한다.

## 4. 검증

- 커밋된 blob의 SHA-256과 backend main raw 파일의 SHA-256 일치 확인 (`bd20239b…2645`).
- `openapi-drift` 잡은 PR을 올려 GitHub Actions에서 통과를 확인한다.
- Dart 코드 변경이 없으므로 포맷·분석·테스트는 이 브랜치에서 재검증 대상 아님.

## 5. 이후 작업에서 지킬 것

- CI의 `openapi-drift`가 실패하면: backend의 스펙 변경이 클라이언트(`lib/features/*/data/`)에 미치는 영향을 먼저 확인하고, 필요한 클라이언트 수정과 함께 `docs/openapi.json`을 같은 PR에서 갱신한다. 갱신은 `curl -fsSL https://raw.githubusercontent.com/Cook-Pilot/backend/main/docs/openapi.json -o docs/openapi.json`.
- API 클라이언트를 새로 작성하거나 수정할 때는 `docs/openapi.json`의 해당 경로 스키마를 근거로 삼는다.
- 클라이언트 코드 생성(openapi-generator) 도입을 검토할 때는 이 사본 파일을 입력으로 쓴다.
