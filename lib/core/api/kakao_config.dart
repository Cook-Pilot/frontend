/// 카카오 네이티브 앱 키.
///
/// 앱에 embed 되는 **공개 값**이라 비밀이 아니다 — 카카오는 이 키가 아니라
/// 등록된 키 해시(앱 서명)로 정당한 앱인지 검증한다. 그래서 저장소에 두어도 된다.
/// 키를 바꿔야 하면 빌드 시 --dart-define=KAKAO_NATIVE_APP_KEY=... 로 덮어쓴다.
const kakaoNativeAppKey = String.fromEnvironment(
  'KAKAO_NATIVE_APP_KEY',
  defaultValue: 'c7cffdeb995c2993764e5ec94d032c8e',
);
