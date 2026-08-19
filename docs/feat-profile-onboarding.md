# 성별·연령대 온보딩

## 문제 상황

백엔드에 `GET/PATCH /api/v1/users/me` 프로필 스펙이 추가됐다.
로그인 성공 후 `profileAskedAt`이 null이면 성별·연령대 온보딩을 한 번 보여주고,
입력하든 건너뛰든 PATCH를 보내 서버에 "물어봤음"을 기록해야 한다.
"신규 유저냐"로 판단하면 온보딩 도중 이탈·기기 변경 케이스가 깨지므로
판단 기준은 `profileAskedAt == null` 하나다.

## 검토한 대안

- **인증 헤더**: 스펙 문서는 `Authorization: Bearer`를 언급하지만, 로컬 백엔드 실측 결과
  베타 사용자는 기존 `X-CookPilot-User-Id` 헤더가 그대로 유효했다. 기존 방식을 유지한다.
- **프로필 모델**: `UserProfile` 모델을 만들었다가 삭제했다. 프론트가 실제로 쓰는 값은
  `profileAskedAt`의 null 여부뿐이라 `needsOnboarding(): Future<bool>`로 축소했다.
- **확인 버튼 활성 조건**: 백엔드가 부분 입력(`gender`만 등)을 허용하는 것을 실측 확인해,
  하나라도 고르면 활성화하고 고른 값만 전송한다. 아무것도 안 고르는 경로는 건너뛰기가 담당한다.

## 최종 결정

- `lib/features/user/data/user_profile_repository.dart` (신규)
  - `needsOnboarding()`: GET 후 `profileAskedAt == null` 판정.
    필드 자체가 없는 구버전 서버 응답에는 온보딩을 띄우지 않는다
    (프론트가 먼저 배포돼도 매 로그인 온보딩이 뜨는 사고 방지).
  - `updateProfile({gender, ageGroup})`: 고른 값만 PATCH body에 담는다.
    둘 다 null이면 빈 body로 "물어봤음"만 기록한다(건너뛰기).
- `lib/features/mvp/profile_onboarding_screen.dart` (신규)
  - 성별 3택·연령대 6택 ChoiceChip, 수집 목적 문구 "맞춤 추천을 위해 사용돼요 (선택)".
  - 건너뛰기: 화면은 바로 홈으로 넘기고 뒤에서 조용히 빈 body PATCH, 실패는 무시
    (다음 로그인에서 온보딩이 다시 뜰 뿐이다).
  - 확인: PATCH 성공 시 홈, 실패 시 SnackBar 후 화면 유지.
- `lib/features/mvp/auth_screen.dart`
  - `_openHome`: `ensureUser()` 후 `needsOnboarding()` 분기. 프로필 조회 실패나
    지연은 홈 진입을 막지 않는다(온보딩은 다음 로그인에서 다시 시도).
    이 호출만 `requestTimeout: 3초`로 줄였다 — 기본 8초면 서버가 죽었을 때
    로그인 직후 8초를 멈춘 채 기다리게 된다.

## 검증

- `test/features/user/data/user_profile_repository_test.dart`
  - 온보딩 판정 3분기(null/값 있음/필드 없음), PATCH body 3종(부분/전체/빈 body)
- `test/features/mvp/profile_onboarding_screen_test.dart`
  - 선택 전 확인 비활성 → 하나 선택 시 고른 값만 전송, 건너뛰기 빈 body 전송
- `test/features/mvp/auth_onboarding_flow_test.dart`
  - 로그인 후 `needsOnboarding` true → 온보딩 화면, false → `MainShell`,
    프로필 조회 실패(500) → `MainShell`
- 로컬 백엔드 실측: 부분 입력 허용, 빈 body로 `profileAskedAt` 기록,
  허용값 밖(`gender: "X"`)은 400 확인
- `flutter analyze` 0 issues, `dart format` clean
- `flutter test`는 WSL 환경의 파일락 문제로 Windows 로컬에서 실행

## 코파일럿 리뷰 대응 (PR #55)

- `jsonEncode({'gender': ?gender, ...})`가 문법 오류라는 지적은 오탐.
  Dart 3.9 null-aware element이고 SDK는 `^3.12.2`, `flutter analyze` 0 issues.
- 홈 진입이 프로필 조회 타임아웃(기본 8초)만큼 지연된다는 지적은 유효.
  이 호출만 `requestTimeout: 3초`로 줄여 반영했다.
- `_openHome`의 온보딩 분기 위젯 테스트 부재 지적은 유효해 반영했다.
  `AuthScreen`에 `profileRepository` 주입 파라미터(테스트 전용, 앱에서는 null)를
  두고 `test/features/mvp/auth_onboarding_flow_test.dart`로 3분기를 덮었다.
  `BetaUserRepository`는 세션에 사용자가 있으면 네트워크를 타지 않으므로
  `BetaUserSession.setCurrentUser`로 충분해 주입 지점을 만들지 않았다.

## 이후 작업에서 지킬 것

- 온보딩 노출 여부는 항상 서버의 `profileAskedAt`으로만 판단한다.
  로컬 저장소에 "물어봤음" 플래그를 두지 않는다.
- 소셜 로그인(Bearer 토큰) 도입 시 `UserProfileRepository`의 헤더 생성부만 교체하면 된다.
