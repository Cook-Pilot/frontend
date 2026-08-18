# feat/social-login-dev — 로그인 세션 기반과 개발자 로그인

## 문제 상황

지금 앱은 시작하면 서버에서 **익명 UUID 를 발급받아** 헤더(`X-CookPilot-User-Id`)에 그대로 실어 보낸다. UUID 를 아는 사람은 누구나 그 계정으로 행세할 수 있고, 로그인 화면(`AuthScreen`)의 카카오·구글 버튼은 목이라 눌러도 익명 발급으로 이어진다.

백엔드에 소셜 로그인과 세션 토큰(JWT)이 추가됐으므로(backend `feat/social-login`), 클라이언트에 **토큰 기반 세션**을 붙인다.

## 검토한 대안

**한 번에 카카오·구글까지 붙일지** 고민했다. 두 SDK 는 앱 등록(네이티브 앱 키, 패키지명·키해시, 번들 ID)이 선행돼야 **실제로 동작을 확인할 수 없다.** 반면 개발자 로그인은 서버만 있으면 끝까지 검증된다.

그래서 이 브랜치는 **세션 기반 + 개발자 로그인**까지만 한다. 소셜 SDK 는 키 발급 후 같은 틀(`AuthApi.loginWithProvider`)에 끼우면 된다.

## 최종 결정

1. **토큰은 `flutter_secure_storage` 에 둔다.** 세션 토큰은 비밀번호에 준하는 값이라 평문인 SharedPreferences 에 두지 않는다(Android KeyStore / iOS Keychain).
2. **전환기에는 두 인증이 함께 산다.** `BetaUserSession.requestHeaders` 가 토큰이 있으면 `Authorization: Bearer` 를, 없으면 기존 익명 헤더를 낸다. 서버도 같은 규칙이라 **어느 시점에도 앱이 깨지지 않는다.** API 호출부는 한 줄도 고치지 않았다.
3. **만료된 토큰은 없는 것으로 취급한다.** `restore()` 가 만료를 발견하면 저장소를 비우고 실패를 돌려준다 — 만료된 토큰으로 요청해 401 을 받는 것보다 낫다.
4. **7번 탭은 보안이 아니다.** 앱을 뜯으면 누구나 알 수 있는 값이다. 실제 방어는 서버의 `DEV_LOGIN_SECRET` 이고, 서버에 시크릿이 없으면 로그인 자체가 거부된다. 연타 간격(2초)을 둬서 평소 조작으로 우연히 열리지 않게 했다.
5. **로그인 화면 UI 는 건드리지 않았다.** 기존 목업 화면의 로고에 게이트만 씌웠다. 소셜 버튼 연결은 SDK 붙일 때 함께 한다.

## 변경 사항

| 파일 | 내용 |
| --- | --- |
| `features/auth/data/auth_api.dart` | `POST /auth/{provider}`, `POST /auth/dev` 호출. 401·429·5xx 를 사용자 문구로 |
| `features/auth/data/auth_session.dart` | 토큰 보관·복원·만료 판정, `Authorization` 헤더 제공 |
| `features/auth/presentation/developer_login.dart` | 로고 7번 연타 → 시크릿 입력 → 로그인 |
| `features/user/data/beta_user_repository.dart` | `requestHeaders` 가 토큰 우선, 없으면 익명 폴백 |
| `features/mvp/auth_screen.dart` | 로고를 `DeveloperLoginGate` 로 감쌈 |
| `pubspec.yaml` | `flutter_secure_storage` 추가 |

## 앱 시작 시 세션 복원

`main()` 에서 `AuthSession.restore()` 를 호출하고, 결과에 따라 첫 화면을 정한다(복원 성공 → `MainShell`, 실패 → `AuthScreen`). **이게 없으면 토큰을 저장해도 앱을 재시작할 때마다 로그인이 풀린다** — 저장 기능이 무의미해진다.

저장소 읽기는 실패해도 예외를 던지지 않는다(키체인 잠김, 플러그인 미가용 등). 앱 시작 경로라 여기서 던지면 **앱이 아예 뜨지 않는다.** 읽지 못하면 '로그인 안 됨'으로 보고 로그인 화면에서 복구시킨다.

## 검증

- 신규 테스트 12개 (토큰 파싱, provider 경로, 401·429 문구, 만료 판정, 저장·복원·로그아웃, **전환기 헤더 규칙 2건**)
- 앱 시작 분기 위젯 테스트 2개(복원 성공 → 홈, 실패 → 로그인 화면)
- 전체 407개 통과, `flutter analyze` 무경고
- 실제 개발자 로그인은 서버에 `DEV_LOGIN_SECRET` 설정 후 확인 필요

## openapi 사본 갱신

`docs/openapi.json` 을 backend main 과 맞췄다(17 → 20개). 이 브랜치가 쓰는 `POST /auth/dev`·`/auth/{provider}` 가 스펙에 들어오고, 앞서 머지된 `reviews/photos` 도 함께 반영된다. CI 의 `openapi-drift` 는 backend main 과 바이트 비교를 하므로 이 갱신 없이는 통과하지 못한다.

프론트 #50(봇이 만든 사본 갱신 PR)은 `reviews/photos` 만 담고 있어 이미 낡았다 — 이 PR 로 대체되므로 close 하면 된다.

## 이후 작업에서 지킬 것

- **소셜 SDK 를 붙일 때** `AuthApi.loginWithProvider(provider, token)` 만 호출하면 된다. 세션 저장·헤더 적용은 이미 되어 있다.
- **익명 발급 제거는 백엔드 3단계와 함께** 한다. 그때 `BetaUserSession` 의 폴백 분기와 익명 관련 코드를 걷어낸다.
- **HTTPS 전까지 실사용자 로그인을 열지 않는다.** 평문 HTTP 로 토큰이 오가면 탈취될 수 있다.
