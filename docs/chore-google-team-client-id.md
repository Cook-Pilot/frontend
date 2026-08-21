# chore/google-team-client-id — 구글 로그인을 팀 계정 프로젝트로, 팀 공용 debug 서명 키

## 문제 상황

1. 구글 로그인의 웹 클라이언트 ID 가 팀원 개인 구글 계정의 GCP 프로젝트(`831666135740`)에 있었다. 그 사람 계정이 잠기거나 팀을 떠나면 로그인 설정에 손을 못 댄다.
2. 구글 Android 클라이언트와 카카오 키 해시는 **앱 서명(SHA-1)** 으로 앱을 식별하는데, 개발용 서명 키(`~/.android/debug.keystore`)는 **PC 마다 자동 생성되어 전부 다르다.** 그래서 팀원(정확히는 빌드하는 PC)이 늘 때마다 구글 콘솔에 Android 클라이언트를, 카카오 콘솔에 키 해시를 하나씩 더 등록해야 했다. 빠뜨리면 그 PC 빌드에서만 구글 로그인 창이 안 열리고(`DEVELOPER_ERROR`) 카카오는 `keyHash validation failed` 가 난다.

## 검토한 대안

**카카오도 팀 계정으로 옮길지** — 카카오 계정은 휴대폰 번호당 1개라 팀 공용 계정을 만들 수 없다. 카카오 개발자 콘솔은 앱 단위 **팀 관리**(관리자/편집자/뷰어 초대, 마스터 이양)가 있으므로 기존 앱을 유지하고 팀원을 초대하는 것으로 해결한다. 카카오는 회원번호가 앱마다 달라서 앱을 새로 파면 기존 카카오 가입자가 전부 새 계정이 되는 문제도 있다. **키 변경 없음.**

**구글을 IAM 소유자 추가로만 해결할지** — 기존 프로젝트에 팀 계정을 소유자로 넣으면 키 변경 없이 끝난다. 하지만 팀에서 "팀 계정 아래 프로젝트"를 원했고, 구글은 `sub` 가 프로젝트 간 동일해 기존 가입자에 영향이 없으므로 새 프로젝트로 옮긴다.

**debug.keystore 를 각자 복사해 쓸지** — 파일을 따로 전달하면 새 팀원마다 빠뜨린다. 레포에 넣고 gradle 이 가리키게 하면 clone 만으로 같은 서명이 된다.

## 최종 결정

1. **웹 클라이언트 ID 교체** — `lib/core/api/social_config.dart` 기본값을 팀 계정(`cooklog.official@gmail.com`) 프로젝트(`60435838803`)의 웹 애플리케이션 클라이언트 ID 로 바꾼다. 이 값이 ID 토큰의 `aud` 가 되므로 **서버 `GOOGLE_CLIENT_IDS` 도 같이 바꿔야 한다.** 전환기에는 서버에 옛 ID 와 새 ID 를 쉼표로 함께 두어 기존 빌드가 깨지지 않게 하고, 새 빌드가 다 배포되면 옛 ID 를 뺀다.
2. **팀 공용 debug 키를 레포에 둔다** — `android/app/debug.keystore`(alias `androiddebugkey`, 비밀번호 `android`, 안드로이드 기본 debug 키와 같은 규약). `build.gradle.kts` 의 `signingConfigs.debug` 가 이 파일을 가리키므로 **누가 어느 PC 에서 빌드하든 서명이 같다.** release 빌드도 현재는 debug 서명을 쓰므로 함께 통일된다.
   - `android/.gitignore` 의 `**/*.keystore` 에 `!app/debug.keystore` 예외를 뒀다. 출시 키(`key.properties`, `*.jks`)는 여전히 금지다.
   - 비밀번호가 공개된 개발용 키라 **비밀이 아니다.** 구글·카카오 모두 debug 서명은 개발 단계 식별용으로만 쓴다. 스토어 출시 때는 별도 upload 키 + Play 앱 서명 SHA-1 을 추가 등록해야 한다.
3. 이 키의 지문. 콘솔에 **이 값 하나만** 등록하면 된다:
   - SHA-1 (구글 Android 클라이언트): `4C:46:A8:E5:D3:6E:91:75:E1:96:CA:D8:EA:1D:79:AF:AA:AB:6F:D3`
   - 카카오 키 해시 (SHA-1 의 base64): `TEao5dNukXXhlsrY6h15r6qrb9M=`

## 검증

- `flutter analyze` 무경고, `flutter test` 전체 통과
- `flutter build apk --debug` 후 APK 서명 인증서의 SHA-1 이 위 값과 일치하는지 확인

## 이후 작업에서 지킬 것

- **debug.keystore 를 지우거나 재생성하지 않는다.** 바뀌면 구글·카카오 콘솔 등록이 전부 무효가 된다.
- 새 팀원은 콘솔에 아무것도 등록할 필요 없다. 로그인이 안 되면 `~/.android/debug.keystore` 가 쓰이는 게 아닌지(예: Android Studio 가 signingConfig 를 덮어쓰는지) 먼저 의심한다.
- 출시 키를 만들 때는 `key.properties` + `signingConfigs.release` 로 분리하고, 이 debug 설정은 그대로 둔다.
