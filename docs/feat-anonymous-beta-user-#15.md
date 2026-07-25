# #15 익명 베타 사용자 발급·저장

## 목적

실제 소셜 로그인 도입 전에도 폐쇄 베타 참여자의 즐겨찾기, 최근 조리,
리뷰와 개인 레시피를 서로 분리하기 위한 프론트 식별 흐름이다.
로그인 화면 디자인은 유지하지만 시작 버튼은 모두 익명 사용자 준비를 거쳐 홈으로 이동한다.

## 처리 흐름

1. 시작 버튼을 누르면 `BetaUserRepository.ensureUser()`를 호출한다.
2. 현재 앱 세션에 사용자가 있으면 서버 요청 없이 재사용한다.
3. `SharedPreferences`에 UUID가 있으면 `GET /api/v1/users/me`로 유효성을 확인한다.
4. 저장된 UUID가 손상됐거나 서버가 `USER_NOT_FOUND` 코드와 함께 404를 반환하면
   `POST /api/v1/users/anonymous`로 사용자를 복구한다.
5. 발급한 UUID를 기기에 저장하고 `BetaUserSession`에 현재 사용자를 설정한다.
6. 사용자 준비가 끝난 뒤에만 홈 화면으로 이동한다.

일반적인 404, 서버 오류, 복구 요청 실패에는 저장된 UUID를 삭제하지 않는다.
새 사용자 발급과 기기 저장이 모두 끝난 뒤에만 기존 UUID를 교체한다.

## 요청 식별

개인화가 필요한 API 요청에는 다음 헤더를 보낸다.

```http
X-CookPilot-User-Id: <user UUID>
```

`BetaUserSession.requestHeaders`가 헤더 생성을 한 곳에서 담당하며,
레시피·홈·즐겨찾기 저장소가 이를 공통으로 사용한다.
세션이 준비되지 않았다면 빈 헤더를 보내지 않고 요청 전에 오류를 발생시킨다.

## 중복 발급 방지

같은 시점에 여러 버튼이나 화면이 `ensureUser()`를 호출할 수 있다.
정적 `_pendingUser`가 진행 중인 Future를 공유해 익명 사용자 POST 요청이 한 번만 발생하도록 한다.
요청이 성공하거나 실패하면 Future를 정리해 이후 재시도가 가능하다.

기기에는 사용자 UUID와 별도로 설치 UUID를 먼저 저장한다. 익명 사용자 생성 요청에는
이 설치 UUID를 `Idempotency-Key` 헤더로 전달한다. 서버가 사용자를 생성한 뒤 응답이
유실되거나 시간 초과가 발생해도 재시도는 같은 키를 사용하므로 같은 사용자를 돌려받는다.

설치 UUID 또는 발급된 사용자 UUID를 `SharedPreferences`에 저장하지 못하면
`BetaUserSession`에 사용자를 공개하지 않고 진입을 중단한다. 따라서 재시작 후 잃어버릴
사용자 ID로 즐겨찾기나 조리 기록을 생성하지 않는다.

## 주요 변경 파일

- `lib/features/user/data/beta_user_repository.dart`
  - 응답 모델, 로컬 세션, 저장·복구·발급 로직
- `lib/features/mvp/auth_screen.dart`
  - 홈 진입 전 사용자 준비 및 실패 안내
- `lib/core/api/api_config.dart`
  - 기본 API 주소와 `COOKPILOT_API_BASE_URL` 재정의
- `android/app/src/main/AndroidManifest.xml`
  - 배포 빌드의 인터넷 권한
- `android/app/src/debug/AndroidManifest.xml`
  - 에뮬레이터 로컬 HTTP 통신 허용
- `ios/Runner/Info.plist`
  - iOS 개발 중 로컬 백엔드 통신 허용

기본 개발 주소는 Android 에뮬레이터에서 `http://10.0.2.2:8080`,
iOS 시뮬레이터·웹·데스크톱에서 `http://localhost:8080`을 사용한다.
실기기에서는 개발 PC의 LAN 주소가 필요하며, 실제 베타 배포는 HTTPS 주소를
`--dart-define=COOKPILOT_API_BASE_URL=...`로 전달한다.

## 오류 처리

사용자 발급·복구가 실패하면 홈으로 이동하지 않고 SnackBar로 실패 원인을 표시한다.
응답 상태 코드와 JSON 필수 필드도 검증해 잘못된 응답을 사용자 세션으로 저장하지 않는다.
저장된 사용자 UUID의 형식이 손상된 경우에는 서버 GET을 건너뛰고 기존 설치 UUID로
복구한다. 복구나 새 UUID 저장이 실패하면 기존 사용자 UUID와 설치 UUID를 보존한다.

## 검증

- 최초 진입 시 사용자 발급과 UUID 저장
- 로컬 사용자 UUID 저장 실패 시 세션 미설정
- 응답 시간 초과 후 재시도 시 동일한 멱등성 키 사용
- 실행 플랫폼별 안전한 로컬 API 기본 주소
- 앱 재진입 시 같은 사용자 복구
- 일반 경로 404에는 기존 사용자 UUID 유지
- 손상된 사용자 UUID는 GET 없이 복구
- 복구 실패·저장 실패 시 기존 UUID와 설치 UUID 유지
- 세션이 없으면 개인화 요청 헤더 생성 차단
- 동시 호출 시 POST 한 번만 수행
- `flutter analyze`
- 전체 Flutter 테스트
- Android 에뮬레이터에서 저장 사용자 복구와 사용자 헤더 전송 확인
