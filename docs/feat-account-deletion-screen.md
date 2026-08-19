# feat/account-deletion-screen — 계정 삭제(회원 탈퇴) 화면

## 문제 상황

개인정보처리방침 초안 v2.4 제9조가 "계정과 모든 개인정보를 한 번에 삭제"를 약속하고,
Google Play(앱 내 삭제 경로 필수)와 Apple 심사지침 5.1.1(v)도 앱 내 계정 삭제를 요구하는데
앱에 탈퇴 경로가 없었다. 백엔드 `DELETE /api/v1/users/me` 는 backend#79 로 만들어졌고
(backend PR #81), 이 브랜치는 그 프론트 절반이다.

## 검토한 대안

- **전용 설정 화면 신설**: 지금 앱에는 설정 화면 자체가 없고 계정 동작은 홈 우상단
  아바타의 계정 시트(로그아웃)가 전부다. 탈퇴 하나를 위해 화면을 새로 만드는 대신
  **기존 계정 시트에 항목을 추가**했다 — 설정 화면이 생기면 그때 옮긴다.
- **로컬 먼저 정리 후 서버 호출**: 기각. 서버 삭제가 실패했을 때 세션이 이미 지워져
  있으면 재시도 자체가 불가능해진다. 서버 204 이후에만 로컬을 지운다.

## 최종 결정

- 계정 시트에 "회원 탈퇴"(error 색) 추가 → 재확인 다이얼로그(무엇이 삭제되는지 명시,
  되돌릴 수 없음 고지) → 진행 다이얼로그(이중 탭 방지) → 서버 삭제 → 로컬 정리 →
  첫 화면으로 복귀(`pushAndRemoveUntil`).
- `AccountDeletionRepository.deleteAccount()`: 204 성공. **404 USER_NOT_FOUND 도 성공** —
  앞선 시도가 서버에서 끝났는데 응답만 유실된 재시도 경로다(서버 멱등 규칙과 짝).
  그 외는 예외 → 스낵바로 실패 안내, 세션 유지.
- `LocalAccountDataWiper`: 세션 토큰(secure storage)·익명 사용자 id(SharedPreferences)·
  후기 사진 파일 전체(`review_photos/`)·작성 중 후기 초안을 지운다. 방침의 "사진 파일까지
  삭제"에서 기기 쪽 절반. **각 단계 best-effort** — 서버 삭제가 이미 끝난 뒤라 여기서
  던지면 사용자가 할 수 있는 게 없다.
- 설치 id(installation id)는 남긴다 — 계정이 아니라 기기 식별이고, 재가입 시 익명 발급
  멱등키로 재사용돼도 서버 행이 이미 없어 새 계정이 된다.
- 저장된 사용자 id 를 지우는 건 즉시성 때문이다. 남아 있어도 다음 부팅의
  `_findSavedUser` 가 404 를 받아 재발급으로 자가 복구하지만, 지우는 쪽이 명확하다.
- 인터페이스 확장: `BetaUserStorage.clearUserId()`, `ReviewPhotoFileGateway.clearAll()`.

## 검증

- `account_deletion_repository_test.dart`: 204/404(USER_NOT_FOUND) 성공, 그 외 404·5xx 예외.
  wiper 가 세션·저장 id·사진·초안을 모두 지우는지, 한 단계 실패에도 나머지를 지우는지.
- `account_sheet_test.dart`(위젯): 재확인 통과 → DELETE 호출 → 첫 화면 복귀 /
  취소 시 아무 동작 없음 / 서버 실패 시 화면 유지 + 실패 스낵바.
- `dart format` · `flutter analyze`(0 issue) · `flutter test` 전체 통과.
- 실기기 확인 필요(배포 후): 탈퇴 → 서버 데이터·S3 객체 삭제, 앱 재시작 시 새 익명 계정,
  같은 소셜 계정 재로그인 시 새 userId.

## 이후 작업에서 지킬 것

- 위젯 테스트에서 `AuthSession` 을 건드리는 경로는 `AuthSession.debugUseStorage` 로
  인메모리 저장소를 주입할 것 — 실제 secure storage 는 테스트 환경에 플러그인이 없어
  호출이 끝나지 않는다(pumpAndSettle 타임아웃으로 나타난다).
- 설정 화면이 생기면 계정 시트의 탈퇴 항목을 그쪽으로 옮기고, 웹 삭제 요청 페이지
  (Play 양식용, Cook-Pilot/web)와 문구를 맞출 것.
