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
| `features/auth/data/kakao_login.dart` | 카카오 액세스 토큰 획득(카카오톡/웹 분기) |
| `features/auth/data/google_login.dart` | 구글 ID 토큰 획득 |
| `features/auth/data/naver_login.dart` | 네이버 액세스 토큰 획득(취소=`loggedOut` 구분) |
| `core/api/social_config.dart` | 카카오 네이티브 앱 키·구글 웹 클라이언트 ID(둘 다 공개 값) |
| `pubspec.yaml` | `flutter_secure_storage`, `kakao_flutter_sdk_user`, `google_sign_in`, `flutter_naver_login` 추가 |

## 앱 시작 시 세션 복원

`main()` 에서 `AuthSession.restore()` 를 호출하고, 결과에 따라 첫 화면을 정한다(복원 성공 → `MainShell`, 실패 → `AuthScreen`). **이게 없으면 토큰을 저장해도 앱을 재시작할 때마다 로그인이 풀린다** — 저장 기능이 무의미해진다.

저장소 읽기는 실패해도 예외를 던지지 않는다(키체인 잠김, 플러그인 미가용 등). 앱 시작 경로라 여기서 던지면 **앱이 아예 뜨지 않는다.** 읽지 못하면 '로그인 안 됨'으로 보고 로그인 화면에서 복구시킨다.

## 로그아웃 (홈 우상단 아바타)

홈 우상단 사람 아이콘은 아무 동작이 없었다. 여기에 계정 시트를 붙이고 **로그아웃 → 첫 화면(로그인)** 경로를 만든다.

세션 복원이 붙은 뒤로는 이 경로가 없으면 **앱을 지우지 않는 한 계정을 바꿀 수 없다.** `AuthSession.signOut()` 은 이미 있었지만 아무도 호출하지 않는 죽은 코드였다.

첫 화면을 인자(`firstScreen`)로 받는다 — 시트에서 로그인 화면을 직접 import 하면 auth 와 mvp 가 서로를 참조하게 된다(`mvp/auth_screen` 은 이미 `auth/presentation` 을 쓴다).

## 검증

- 신규 테스트 12개 (토큰 파싱, provider 경로, 401·429 문구, 만료 판정, 저장·복원·로그아웃, **전환기 헤더 규칙 2건**)
- 앱 시작 분기 위젯 테스트 2개(복원 성공 → 홈, 실패 → 로그인 화면)
- 로그아웃 위젯 테스트 2개(세션·저장소 정리 후 첫 화면 이동 / 시트만 닫으면 세션 유지)
- 전체 409개 통과, `flutter analyze` 무경고
- 실제 개발자 로그인은 서버에 `DEV_LOGIN_SECRET` 설정 후 확인 필요

## 카카오 로그인

로그인 화면의 '카카오로 시작하기' 버튼이 실제 로그인으로 연결된다(그 전에는 익명 발급으로 이어지는 목이었다).

```
카카오 SDK 로그인 → 액세스 토큰
  → POST /auth/kakao {"token": "..."}   서버가 카카오에 되물어 검증
  → 우리 세션 토큰 저장 → 홈
```

- **앱 키는 반드시 '네이티브 앱 키'여야 한다.** 카카오 키는 네 종류(네이티브/REST API/JavaScript/Admin)인데 전부 32자 16진수라 구분이 안 된다. 다른 키를 쓰면 **동의 화면까지는 뜨고 토큰 발급에서 `Android keyHash validation failed`** 로 실패한다(실제로 겪었다 — 키 해시는 맞는데 계속 거부당했다).
- **키 해시가 안 맞을 때는 앱이 계산한 값을 찍어 대조한다.** `KakaoSdk.platformInfo.origin` 이 SDK 가 실제로 보내는 값이다. 개발자마다 다르므로 팀원은 각자 콘솔에 등록해야 한다. `main()` 에 디버그 로그를 남겨 두었다.
- **웹 로그인 복귀 경로는 `AuthCodeHandlerActivity`(`kakao<앱키>://oauth`)다.** 처음에 `AppsHandlerActivity`(`host=address`)에 스킴을 넣었다가 **동의까지 마쳐도 앱으로 돌아오지 못해 무한 로딩**이 됐다 — 그쪽은 카카오싱크·앱 연결용이라 로그인과 무관하다. 빌드된 APK 의 매니페스트를 열어 스킴이 붙은 액티비티를 확인하는 게 확실하다.
- **카카오톡 설치 여부로 분기한다.** 설치돼 있으면 앱으로, 아니면 웹 계정 로그인으로 간다. 카카오톡이 있어도 실패하면(로그인 안 된 카카오톡 등) 웹으로 한 번 더 시도한다.
- **사용자 취소는 오류가 아니다.** `KakaoLoginCancelled` 로 구분해 실패 안내를 띄우지 않는다.
- **네이티브 앱 키는 비밀이 아니다.** 앱에 embed 되는 공개 값이고, 카카오는 이 키가 아니라 **등록된 키 해시(앱 서명)** 로 정당한 앱인지 검증한다. 그래서 저장소에 두되, 바꿔야 할 때를 위해 Dart 는 `--dart-define=KAKAO_NATIVE_APP_KEY`, Android 는 gradle 속성 `kakaoNativeAppKey` 로 덮어쓸 수 있게 했다.
- **AndroidManifest 의 리다이렉트 스킴은 빌드 타임에 확정된다** — `--dart-define` 으로는 못 바꾸므로 gradle `manifestPlaceholders` 로 주입한다. Dart 기본값과 같은 값을 유지해야 한다.

이메일 동의항목은 신청하지 않았다. 카카오는 이메일 제공에 **비즈 앱 전환**이 필요한데, 백엔드가 계정을 이메일이 아니라 카카오 회원번호로 식별하므로 없이도 동작한다.

## 구글 로그인

'Google로 시작하기' 버튼도 실제 로그인으로 연결된다.

```
구글 SDK 로그인 → ID 토큰(JWT)
  → POST /auth/google {"token": "..."}   서버가 구글 공개키(JWKS)로 검증
  → 우리 세션 토큰 저장 → 홈
```

- **`serverClientId` 로 웹 클라이언트 ID 를 넘겨야 ID 토큰이 발급된다.** 이름이 '웹'이라 헷갈리지만 안드로이드 로그인에도 필요하다 — 앱이 받는 ID 토큰의 대상(`aud`)이 이 값으로 찍히고, 서버는 그 `aud` 를 검사한다(`GOOGLE_CLIENT_IDS` 와 같은 값이어야 한다). 이걸 모르면 "토큰은 받았는데 서버가 계속 거부"에 빠진다.
- **안드로이드 클라이언트 ID 는 코드에 넣지 않는다.** 구글이 패키지명 + SHA-1 로 알아서 매칭한다.
- **클라이언트 보안 비밀(client secret)은 쓰지 않는다.** 앱이 ID 토큰을 직접 받고 서버가 공개키로 검증하므로 개입할 자리가 없다. 저장소·서버 어디에도 두지 않는다.
- 취소(`GoogleSignInExceptionCode.canceled`)는 오류로 다루지 않는다.
- `initialize()` 는 한 번만 호출한다.

## 네이버 로그인

카카오와 같은 **액세스 토큰 방식**이다(네이버는 OIDC ID 토큰을 주지 않는다).

```
앱: FlutterNaverLogin.logIn() → NaverLoginResult.accessToken
  → POST /auth/naver {"token": "..."}   서버가 네이버 프로필 API 에 되물어 검증(backend#91)
```

- **MainActivity 는 `FlutterFragmentActivity` 여야 한다.** 플러그인이 Activity 를 그 타입으로 캐스팅해 `registerForActivityResult` 를 쓴다. `FlutterActivity` 인 채로 두면 로그인 버튼을 누르기도 전에 **앱 시작 시 ClassCastException** 으로 죽는다.
- **Client ID/Secret 은 Dart 가 아니라 Android 매니페스트 meta-data 로 읽는다.** `build.gradle.kts` 가 `android/local.properties`(gitignored)의 `naver.clientId` / `naver.clientSecret` 을 `manifestPlaceholders` 로 주입한다. Secret 이 APK 에 들어가는 것은 네이버 Android SDK 의 구조라 피할 수 없지만, 저장소에는 남기지 않는다.
- **버튼은 `NAVER_CLIENT_ID` dart-define 이 있을 때만 그린다**(`social_config.dart`). 팀계정 애플리케이션이 아직 없어 기본값이 비어 있다. 발급되면 카카오 키처럼 기본값으로 박는다(ID 는 공개 값).
- **취소는 `status == loggedOut` 으로 온다.** 플러그인이 `user_cancel` 을 그렇게 매핑한다. `NaverLoginCancelled` 로 구분해 실패 안내를 띄우지 않는다. `error` 는 `errorMessage` 를 로그로 남기고 일반 문구를 보인다.
- **회원 식별자는 애플리케이션 단위다**(카카오와 같음). 실사용자 개방 전에 팀계정 애플리케이션으로 확정해야 한다.
- **iOS 는 아직 안 붙였다** — 카카오도 iOS 설정(URL 스킴)이 없는 상태라 같이 한다. 필요 시 `Info.plist` 의 `NidUrlScheme`/`NidClientID`/`NidClientSecret`/`NidAppName` + `LSApplicationQueriesSchemes`(naversearchapp, naversearchthirdlogin) + AppDelegate `NidOAuth.shared.handleURL`.

로컬에서 켜는 법:

```
# android/local.properties
naver.clientId=발급받은_Client_ID
naver.clientSecret=발급받은_Client_Secret

flutter run --dart-define=NAVER_CLIENT_ID=발급받은_Client_ID
```

네이버 개발자센터에는 Android 패키지명 `com.cookpilot.cookpilot` 과 다운로드 URL(스토어 등록 전엔 아무 URL) 을 등록하고, 제공 정보는 회원 식별자(필수)·이메일·별명(선택)으로 둔다.

## openapi 사본 갱신

`docs/openapi.json` 을 backend main 과 맞췄다(17 → 20개). 이 브랜치가 쓰는 `POST /auth/dev`·`/auth/{provider}` 가 스펙에 들어오고, 앞서 머지된 `reviews/photos` 도 함께 반영된다. CI 의 `openapi-drift` 는 backend main 과 바이트 비교를 하므로 이 갱신 없이는 통과하지 못한다.

프론트 #50(봇이 만든 사본 갱신 PR)은 `reviews/photos` 만 담고 있어 이미 낡았다 — 이 PR 로 대체되므로 close 하면 된다.

## 이후 작업에서 지킬 것

- **소셜 SDK 를 붙일 때** `AuthApi.loginWithProvider(provider, token)` 만 호출하면 된다. 세션 저장·헤더 적용은 이미 되어 있다.
- **익명 발급 제거는 백엔드 3단계와 함께** 한다. 그때 `BetaUserSession` 의 폴백 분기와 익명 관련 코드를 걷어낸다.
- **HTTPS 전까지 실사용자 로그인을 열지 않는다.** 평문 HTTP 로 토큰이 오가면 탈취될 수 있다.
