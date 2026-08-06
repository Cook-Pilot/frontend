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
- 검토한 대안 2: openapi-generator로 Dart 클라이언트 생성 — 실제로 `dart-dio`·`dart` 생성기를 돌려 검증한 결과(아래) 현시점 도입 부적합으로 제외.
  - 스펙의 모든 스키마에 `required` 선언이 없어 생성 모델의 전 필드가 nullable로 나온다(`String? id` 등). 이를 쓰면 프론트 전역에 null 체크·`!`가 강제되어 non-null로 정확히 손질한 현재 수동 모델보다 오히려 나쁘다.
  - 프론트 모델은 wire DTO가 아니다. 수동 `Recipe`는 스펙의 `Recipe` + `RecipeSummaryResponse` 필드를 합치고 파생 getter(타이머 합산, 한국어 라벨)를 얹은 뷰모델이라, 생성 DTO를 도입해도 DTO→도메인 매핑 층이 추가로 필요해 코드가 오히려 늘어난다.
  - 생성 규모: `dart-dio` 기준 126파일 + dio·built_value·build_runner 의존성. 린트 제외 설정도 필요.
  - 재검토 조건: backend 스펙에 `required`/nullable이 정확히 선언되고, 엔드포인트 수·변경 빈도가 수동 유지비를 넘어설 때. 그 경우에도 전체 클라이언트가 아니라 모델(DTO)만 생성하는 절충부터 시작한다.
- 최종 결정: 사본 커밋 + CI 바이트 비교(드리프트 감지)만 도입.

### CI 드리프트 검사 (`.github/workflows/ci.yml`)

`openapi-drift` 잡을 추가했다. backend main의 raw `docs/openapi.json`을 curl로 받아 커밋된 사본과 `diff`로 비교하고, 다르면 실패시킨다. backend가 스펙을 정규화해 두므로 바이트 비교로 충분하다. 소요 시간은 수 초라 기존 `check` 잡과 병렬로 돌며 전체 CI 시간에 영향이 없다.

### 사본 자동 갱신 (`.github/workflows/openapi-sync.yml`)

매일 1회(KST 09:00) backend main의 스펙을 받아 사본과 다르면 갱신 PR을 자동 생성한다(`peter-evans/create-pull-request`, 브랜치 `chore/openapi-sync-bot`). 스케줄 잡은 main의 워크플로우 파일 기준으로 돌므로 이 브랜치가 머지된 뒤부터 동작하고, `workflow_dispatch`로 수동 실행도 가능하다.

- 자동화 범위는 PR 생성까지다. 자동 머지는 하지 않는다 — 스펙 변경의 클라이언트 영향 판단은 사람 몫이며, 봇 PR은 diff가 첨부된 알림 역할이다.
- 검토한 대안: backend 푸시 시 `repository_dispatch`로 즉시 트리거 — cross-repo 토큰과 backend 리포 수정이 필요해, 하루 1회면 충분한 현시점에는 제외.
- 기존 `openapi-drift` 잡과의 관계: cron은 능동적 알림, drift 잡은 어긋난 채 머지되는 것을 막는 방어선으로 역할이 다르므로 둘 다 유지한다.

### 줄바꿈 보존 (`.gitattributes`)

`docs/openapi.json -text`를 추가했다. Windows 로컬(`core.autocrlf=true`)에서 체크아웃·재커밋 시 줄바꿈이 변환되면 backend 원본과 바이트가 어긋나 CI diff가 헛실패하므로, 이 파일은 git의 텍스트 변환에서 제외한다.

## 4. 검증

- 커밋된 blob의 SHA-256과 backend main raw 파일의 SHA-256 일치 확인 (`bd20239b…2645`).
- `openapi-drift` 잡은 PR을 올려 GitHub Actions에서 통과를 확인한다.
- `openapi-sync` 워크플로우는 스케줄 특성상 머지 전에는 돌지 않으므로, 머지 후 Actions 탭에서 `workflow_dispatch`로 1회 수동 실행해 "diff 없음 → PR 미생성"으로 끝나는지 확인한다.
- Dart 코드 변경이 없으므로 포맷·분석·테스트는 이 브랜치에서 재검증 대상 아님.

## 5. 이후 작업에서 지킬 것

- CI의 `openapi-drift`가 실패하면: backend의 스펙 변경이 클라이언트(`lib/features/*/data/`)에 미치는 영향을 먼저 확인하고, 필요한 클라이언트 수정과 함께 `docs/openapi.json`을 같은 PR에서 갱신한다. 갱신은 `curl -fsSL https://raw.githubusercontent.com/Cook-Pilot/backend/main/docs/openapi.json -o docs/openapi.json`.
- API 클라이언트를 새로 작성하거나 수정할 때는 `docs/openapi.json`의 해당 경로 스키마를 근거로 삼는다.
- 클라이언트 코드 생성(openapi-generator) 도입을 검토할 때는 이 사본 파일을 입력으로 쓴다.
