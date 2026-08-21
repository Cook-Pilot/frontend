# feat/apple-login — 애플 로그인 버튼 (iOS)

## 문제 상황

로그인 화면에 카카오·구글만 있다. iOS 앱이 다른 소셜 로그인을 제공하면 **애플 로그인도 심사 요건**이라
iOS 출시 전에 붙여야 한다. 서버는 backend `feat/apple-login` 으로 `POST /auth/apple` 을 연다.

## 검토한 대안

- **안드로이드에도 같이 노출** — 애플 로그인은 안드로이드에서 웹 리다이렉트 방식이라 Services ID 와
  서버 콜백 엔드포인트(`/callbacks/sign_in_with_apple`)가 더 필요하다. 심사 요건도 iOS 에만 있다. 제외.
- **패키지 제공 `SignInWithAppleButton` 위젯** — 디자인이 우리 버튼 체계(`PressableScale` + `FilledButton`)와
  어긋난다. 검은 배경 + 애플 로고 + "Apple로 시작하기" 로 같은 모양을 직접 만든다.

## 최종 결정

```
Sign in with Apple (sign_in_with_apple) → identity token + (최초 1회) 이름
  → POST /auth/apple {"token": "...", "displayName": "홍길동"(선택)}   서버가 애플 공개키(JWKS)로 검증
  → 우리 세션 토큰 저장 → 홈
```

- `lib/features/auth/data/apple_login.dart` — `AppleLogin.obtainIdentityToken()`. 구글·카카오와 같은 모양:
  취소는 `AppleLoginCancelled`, 나머지는 `AuthException`.
- **이름은 최초 로그인 1회만 온다.** 애플은 토큰에 이름을 싣지 않고 `givenName`/`familyName` 을 첫 인증에만
  준다. 그래서 그때 받은 이름을 `displayName` 으로 같이 보내고, 서버는 계정 생성 시에만 쓴다. 두 번째부터는
  null 이라 안 보낸다. 한글이 섞이면 `성+이름`(홍길동), 아니면 `이름 성`(Tim Cook).
- `AuthApi.loginWithProvider(..., displayName:)` — 값이 있을 때만 본문에 싣는다. 구글·카카오 호출은 그대로.
- 버튼은 `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS` 일 때만 보이고 **맨 위**에 둔다(애플 HIG:
  다른 로그인보다 덜 눈에 띄면 안 됨).
- iOS 프로젝트: `ios/Runner/Runner.entitlements` 에 `com.apple.developer.applesignin = [Default]` 를 추가하고
  `project.pbxproj` 의 Runner 타깃 세 구성(Debug/Release/Profile)에 `CODE_SIGN_ENTITLEMENTS` 를 걸었다.
  Xcode 에서 "Sign in with Apple" capability 를 켜면 생기는 것과 같은 변경이다.
- 클라이언트에 둘 ID 는 없다. 토큰의 aud 가 번들 ID(`com.cookpilot.cookpilot`)로 찍히고 서버
  `APPLE_CLIENT_IDS` 가 그걸 검사한다(`social_config.dart` 주석).

## 검증

- `flutter analyze` 경고 0, `dart format` 변경 없음, `flutter test` 통과.
- `auth_api_test` — `displayName` 이 있을 때만 본문에 실리는지.
- **실기기 검증은 아직 못 했다.** Apple Developer 계정이 없어 번들 ID 에 Sign in with Apple 을 켤 수 없고,
  그 전에는 `getAppleIDCredential` 이 `AuthorizationErrorCode.unknown/failed` 로 실패한다. 계정이 생기면:
  1. developer.apple.com → Identifiers → `com.cookpilot.cookpilot` App ID → Sign in with Apple 체크
  2. Xcode 에서 팀 선택(자동 서명)
  3. 서버 `.env` 에 `APPLE_CLIENT_IDS=com.cookpilot.cookpilot`
  4. 실기기에서 'Apple로 시작하기' → 첫 로그인에 이름이 계정에 들어가는지, 두 번째 로그인에 같은 계정인지 확인

## openapi 사본

`docs/openapi.json` 을 backend `feat/apple-login` 의 것으로 갱신했다(`SocialLoginRequest.displayName` 추가).
CI `openapi-drift` 는 backend **main** 과 비교하므로 **backend PR 이 먼저 머지돼야** 통과한다.

## 이후 작업에서 지킬 것

- 탈퇴 시 애플 토큰 revoke(심사 요건)는 서버에 없다. 붙일 때는 로그인 시 `credential.authorizationCode` 도
  서버로 보내야 한다 — `AppleLoginResult` 에 필드 하나 추가하면 된다.
- 안드로이드에 애플 로그인을 열려면 Services ID + `WebAuthenticationOptions(clientId, redirectUri)` + 서버 콜백이
  필요하다. 버튼 노출 조건만 풀면 안 된다.
- 애플 로그인 이름은 한 번 놓치면 다시 못 받는다(사용자가 설정에서 연결을 끊고 다시 해야 함). 첫 로그인 응답을
  서버에 보내기 전에 앱이 죽으면 이름 없는 계정이 된다 — 그래서 서버 기본값 "쿡파일럿 사용자"가 필요하다.
