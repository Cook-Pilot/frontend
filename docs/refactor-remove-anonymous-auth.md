# refactor/remove-anonymous-auth — 익명 발급 제거 (소셜 로그인 3단계)

## 문제 상황

로그인이 실제로 동작하게 된 뒤에도(#51) 앱에는 익명 경로가 그대로 남아 있었다.

- `BetaUserSession.requestHeaders` 가 토큰이 없으면 **기존 익명 헤더로 떨어졌다.** 전환기에는 앱이 깨지지 않게 하는 안전장치였지만, 이제는 로그인을 우회하는 구멍이다.
- 로그인 화면에는 **아무 데도 연결되지 않은 목업**이 남아 있었다 — 이메일·비밀번호 입력칸, '로그인' 버튼, '게스트로 둘러보기', '계정이 없나요? 회원가입'. 넷 다 눌러도 익명 발급으로 이어질 뿐이었다.
- **성별·연령대 온보딩(#55)이 실제 로그인에서는 뜨지 않았다.** 온보딩 분기가 목업 '로그인'·'게스트' 버튼이 타는 `_openHome` 안에만 있었고, 카카오·구글·개발자 로그인은 `_openHomeDirectly` 로 곧장 홈에 갔다. 목업을 지우면 온보딩에 닿는 길이 아예 없어지므로 이 PR 에서 함께 고친다.

백엔드가 익명 발급을 제거하는 것과 짝을 이루는 작업이다.

## 검토한 대안

**세션이 없을 때 요청 헤더를 어떻게 할지**가 갈림길이었다.

빈 헤더로 그냥 보내면 서버가 401 을 준다. 그러면 화면마다 401 을 따로 해석해야 하고, 실패가 네트워크 오류처럼 보인다. 그래서 **`AuthSession.requestHeaders` 가 던지게** 했다 — 기존 `BetaUserSession` 도 같은 자리에서 던졌으므로 호출부 8곳의 동작(`세션이 없으면 HTTP 요청을 보내지 않는다`)이 그대로 유지된다.

## 최종 결정

1. **API 호출부는 `AuthSession.requestHeaders` 하나만 본다.** 8곳이 `BetaUserSession` 대신 이걸 쓴다. 폴백 분기가 없어졌으므로 토큰이 없으면 요청 자체가 나가지 않는다.
2. **`beta_user_repository.dart` 를 통째로 지운다.** 익명 발급, 기기 UUID 생성, SharedPreferences 저장까지 전부 이 파일에 있었고 다른 쓰임새가 없다.
3. **로그인 화면은 소셜 버튼 둘만 남긴다.** 목업 입력칸과 게스트·회원가입 버튼을 지웠다. "따로 가입할 필요 없어요" 한 줄을 대신 넣었다 — 회원가입 링크가 사라진 이유를 사용자가 알 수 있어야 한다.
4. **온보딩 분기를 `homeAfterLogin()` 으로 빼고 모든 로그인 경로가 지나가게 한다.** 이제 카카오·구글·개발자 로그인 모두 프로필을 물어봤는지 확인한 뒤 홈으로 간다. 화면 전환에서 분리한 이유는 테스트다 — 위젯 테스트가 소셜 SDK 를 탈 수 없어 버튼을 눌러서는 분기를 검증할 수 없다. `AuthScreen` 의 `profileRepository` 주입 파라미터는 이 함수로 옮겨가 더 이상 쓰이지 않으므로 제거했다.
5. **`TasteProfileScreen` 도 함께 지운다.** '회원가입' 버튼이 유일한 진입점이었다. **#55 의 온보딩과는 다른 화면이다** — 그쪽은 성별·연령대를 서버에 저장하지만, 이쪽은 입맛·맵기를 고르게 해 놓고 아무 데도 보내지 않는 목업이다. 백엔드에 입맛 컬럼도 API 도 없어 지금 살릴 방법이 없다. 입맛 수집을 진짜 기능으로 만들 때 온보딩 화면에 이어 붙이는 편이 낫다.

## 변경 사항

| 파일 | 내용 |
| --- | --- |
| `features/auth/data/auth_session.dart` | 세션이 없거나 만료면 `AuthException` 을 던진다(빈 맵 반환 폐기) |
| `features/user/data/beta_user_repository.dart` | **삭제** (260줄) |
| `features/mvp/auth_screen.dart` | 목업 UI 와 `TasteProfileScreen` 삭제, 온보딩 분기를 `homeAfterLogin()` 으로 추출 |
| `features/user/data/user_profile_repository.dart` | 헤더 출처를 `AuthSession` 으로, 예외를 `AuthException` 으로 |
| `features/{recipe,review,recommendation,cooking}/data/*.dart` | 헤더 출처를 `AuthSession` 으로 (8곳) |
| `test/helpers/auth_fakes.dart` | **신규** — `signInForTest()`, `resetAuthForTest()`, `FakeTokenStorage` |
| `docs/openapi.json` | backend main 과 동기화(익명 발급 경로 1개 + 필드 2개 감소) |

## 검증

- 전체 402개 통과, `flutter analyze` 무경고
- API 테스트 9개 파일이 익명 세션 대신 실제 토큰 세션으로 요청을 검증한다(`Authorization: Bearer …`)
- 삭제: `beta_user_repository_test.dart`(12건), 전환기 헤더 규칙(2건) — 검증 대상 코드가 사라졌다
- 추가: 로그인 전/만료 후 헤더 생성이 각각 던지는지(2건)
- 온보딩 3분기 테스트는 `homeAfterLogin()` 을 직접 부르는 형태로 바꿨다(위젯 펌프 → 함수 호출). 검증하는 분기는 그대로다

## 이후 작업에서 지킬 것

- **백엔드를 먼저 머지·배포한 뒤 이 PR 을 머지한다.** `docs/openapi.json` 동기화 검사(`openapi-drift`)가 backend main 과 바이트 비교를 하므로, 순서가 바뀌면 CI 가 빨갛게 뜬다.
- **세션 복원으로 들어오면 온보딩을 건너뛴다.** `main()` 의 `AuthSession.restore()` 경로는 곧장 `MainShell` 로 간다(#55 때부터 그랬다). 14일 안에 다시 로그인하지 않는 사용자는 온보딩을 못 본다.
- **토큰이 만료되면 지금은 화면마다 오류 문구만 뜬다.** 재로그인으로 유도하는 흐름은 아직 없다(백엔드 #66 리프레시 토큰과 함께 다룬다).
- **HTTPS 전까지 실사용자 로그인을 열지 않는다.** 이제 익명 폴백이 없어 토큰이 유일한 신원이라 탈취의 대가가 더 커졌다.
