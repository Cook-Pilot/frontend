# AGENT.md

CookPilot Flutter 클라이언트(`cookpilot`)에서 AI 코딩 에이전트가 따라야 할 규칙과 컨텍스트.

## 명령어

```bash
flutter pub get          # 의존성 설치
dart format .            # 포맷 (CI에서 --set-exit-if-changed로 강제)
flutter analyze          # 정적 분석 (경고 0 유지)
flutter test             # 전체 테스트
flutter test test/features/cooking/  # 특정 디렉토리만
flutter run --dart-define=COOKPILOT_API_BASE_URL=https://api.example.com  # 실기기/베타 서버
```

CI(`.github/workflows/ci.yml`)는 PR마다 `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`를 실행한다. 커밋 전에 셋 다 로컬에서 통과시킬 것.

## 아키텍처

feature-first 구조. 각 기능은 `lib/features/<기능>/` 아래에 layer별로 나뉜다.

```
lib/
  app/                  # 앱 루트, 테마 (Pretendard 폰트)
  core/                 # api_config(베이스 URL 결정), uuid 등 공용 유틸
  design/               # 스페이싱 등 디자인 토큰
  features/
    cooking/            # 조리 세션: domain / application / presentation 3층 분리
      domain/           #   순수 Dart 모델·로직 (Flutter 의존 없음)
      application/      #   컨트롤러, 포트(인터페이스), 스토어
      presentation/     #   위젯, 네이티브 연동(STT, 로컬 알림)
    mvp/                # 화면 셸: 인증, 메인 셸, 조리 플로우 화면
    recipe/, review/, recommendation/, user/  # API 클라이언트(data/)와 모델(domain/)
test/                   # lib/ 구조를 미러링. test/helpers/에 공용 fake
```

핵심 패턴:
- **포트/어댑터**: `cooking/application/cooking_ports.dart`에 인터페이스를 정의하고 presentation에서 구현(예: `TimerAlarmPort` ← `LocalNotificationTimerAlarm`). 테스트는 `test/helpers/cooking_fakes.dart`의 fake를 사용한다.
- **domain 층은 Flutter 무의존**: `cooking/domain/`에는 Flutter import를 넣지 않는다.
- 백엔드 주소는 `core/api/api_config.dart`가 플랫폼별로 결정한다(에뮬레이터 `10.0.2.2:8080` 등). 하드코딩 금지.

## 코드 컨벤션

- 주석과 사용자 노출 문자열은 한국어. 주석은 "무엇"이 아니라 코드로 드러나지 않는 제약·이유를 적는다.
- 린트: `flutter_lints` + `prefer_single_quotes`, `always_declare_return_types`, `unawaited_futures`, `discarded_futures`. 의도적 fire-and-forget(내비게이션 push 등)은 `unawaited(...)`로 감싼다.
- async가 많은 코드베이스(API, 타이머, STT). Future를 버리지 말고 await하거나 unawaited로 의도를 명시할 것.
- 새 기능에는 테스트를 함께 추가한다. 위치는 `test/`에서 `lib/` 경로를 미러링.

## Git

- 브랜치: `(TAG)/(주요내용)` 예: `feat/login-page`, `fix/token-expire-#99`
- 커밋: `(TAG)((ISSUE)) : 제목` — 이슈 번호는 있을 때만. 예: `feat(#123) : 로그인 API 연동`
- TAG 종류: `feat` `fix` `refactor` `comment` `docs` `rename` `chore` (전체 표는 README.md 참고)
- `main` 직접 push 금지, PR로만 머지.

## 문서

기능 명세는 `docs/`에 있다. 기능을 수정하기 전에 해당 명세(`docs/feat-*.md`)를 먼저 확인할 것.
