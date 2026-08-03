# CI·린트·에이전트 문서 정비 명세서 (feat/ci-set)

## 1. 문서 목적

이 문서는 `feat/ci-set` 브랜치에서 진행한 CI 워크플로 도입, 린트 강화, AI 에이전트용 프로젝트 문서 정비 작업의 배경과 결정 내용을 정의한다.

## 2. 문제 상황

- PR마다 포맷·정적 분석·테스트를 수동으로 돌려야 했고, 누락된 채 머지될 수 있었다.
- API 호출·타이머·STT 등 async가 많은 코드베이스인데 fire-and-forget 실수(await 누락)를 잡는 린트가 없었다.
- AI 코딩 에이전트가 참고할 프로젝트 규칙 문서가 없어 컨벤션(커밋 형식, 아키텍처 제약)이 세션마다 새로 설명되어야 했다.

## 3. 변경 내용

### CI 워크플로 (`.github/workflows/ci.yml`)

PR 생성 시와 `main` push 시 아래 3단계를 실행한다. 커밋 전에 셋 다 로컬에서 통과시킬 것.

| 단계 | 명령 | 기준 |
| --- | --- | --- |
| 포맷 | `dart format --set-exit-if-changed .` | 변경 필요 파일 0 |
| 정적 분석 | `flutter analyze` | 이슈 0 |
| 테스트 | `flutter test` | 전체 통과 |

### 린트 강화 (`analysis_options.yaml`)

`flutter_lints` 기본 세트에 4개 룰 추가:

- `prefer_single_quotes` — 문자열은 홑따옴표
- `always_declare_return_types` — 반환 타입 명시
- `unawaited_futures`, `discarded_futures` — Future를 버리지 않는다. 의도적 fire-and-forget(내비게이션 push, 시스템 사운드 등)은 `unawaited(...)`로 감싸 의도를 명시한다. 기존 위반 10곳을 이 방식으로 정리했다.

### 에이전트 문서 (`AGENTS.md`, `CLAUDE.md`)

- `AGENTS.md` — AI 코딩 에이전트용 단일 문서. 범용 행동 원칙(Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) + 프로젝트 가이드(명령어, 아키텍처, 코드 컨벤션, Git 규칙, 문서 규칙)로 구성한다. 처음 `AGENT.md`로 만들었다가 도구 표준 파일명인 `AGENTS.md`로 통합했다.
- `CLAUDE.md` — 내용 중복 없이 `@AGENTS.md` 참조 한 줄만 둔다.

### 문서 규칙 명문화

PR마다 브랜치 이름으로 `docs/`에 작업 명세를 남기는 규칙을 AGENTS.md에 추가했다. 이 문서가 그 첫 적용 사례다.

## 4. 검증

- `dart format --set-exit-if-changed --output=none .` — 39개 파일 변경 필요 0건
- `flutter analyze` — 이슈 없음
- `flutter test` — 92개 테스트 전체 통과

## 5. 이후 작업에서 지킬 것

- 린트 룰을 추가·해제할 때는 `analysis_options.yaml`에 이유를 주석으로 남긴다.
- 새 fire-and-forget 지점은 `// ignore`가 아니라 `unawaited(...)`로 처리한다.
- 프로젝트 규칙이 바뀌면 AGENTS.md를 같은 PR에서 함께 갱신한다.
