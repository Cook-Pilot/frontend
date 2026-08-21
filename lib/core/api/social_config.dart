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

/// 네이버 애플리케이션 Client ID.
///
/// 비어 있으면 로그인 화면에 네이버 버튼을 **그리지 않는다** — 아직 팀계정 애플리케이션이
/// 없어서 기본값이 비어 있다. 발급되면 카카오처럼 여기 기본값으로 박는다(공개 값).
/// 그 전까지는 `--dart-define=NAVER_CLIENT_ID=...` 로 켠다.
///
/// Android SDK 는 이 값을 Dart 가 아니라 매니페스트 meta-data 에서 읽으므로
/// `android/local.properties` 의 `naver.clientId` / `naver.clientSecret` 도 같이 채워야 한다
/// (build.gradle.kts 가 주입). Secret 은 저장소에 두지 않는다.
const naverClientId = String.fromEnvironment(
  'NAVER_CLIENT_ID',
  defaultValue: '',
);

/// 로그인 화면에 네이버 버튼을 보일지. Client ID 가 있을 때만.
bool get naverLoginEnabled => naverClientId.isNotEmpty;
