/// 소셜 로그인 제공자 설정.
///
/// 카카오 네이티브 앱 키.
///
/// 앱에 embed 되는 **공개 값**이라 비밀이 아니다 — 카카오는 이 키가 아니라
/// 등록된 키 해시(앱 서명)로 정당한 앱인지 검증한다. 그래서 저장소에 두어도 된다.
/// 키를 바꿔야 하면 빌드 시 --dart-define=KAKAO_NATIVE_APP_KEY=... 로 덮어쓴다.
const kakaoNativeAppKey = String.fromEnvironment(
  'KAKAO_NATIVE_APP_KEY',
  defaultValue: '49c1ac97b674198d1b8f7d47f38897f8',
);

/// 애플 로그인은 여기에 둘 값이 없다 — 앱이 받는 identity token 의 대상(aud)이 iOS 번들 ID
/// (`kr.cooklog.app`, Apple Developer 콘솔에 등록된 App ID)로 찍히고, 서버 `APPLE_CLIENT_IDS` 가 그 값을 검사한다.
/// 대신 Xcode 의 Sign in with Apple capability(`ios/Runner/Runner.entitlements`)가 필요하다.

/// 구글 **웹 애플리케이션** 클라이언트 ID.
///
/// 이름이 '웹'이라 헷갈리지만 안드로이드 로그인에도 이게 필요하다 — 앱이 받는 ID 토큰의
/// 대상(aud)이 이 값으로 발급되고, 서버는 그 aud 를 검사한다(GOOGLE_CLIENT_IDS 와 같아야 함).
/// 안드로이드 클라이언트 ID 는 코드에 넣지 않는다. 구글이 패키지명+SHA-1 로 알아서 매칭한다.
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '831666135740-oqqa485r1b5evhsbkcmutk2v8pgqarb6.apps.googleusercontent.com',
);
