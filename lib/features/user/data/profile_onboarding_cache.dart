import '../../auth/data/auth_session.dart';
import 'user_profile_repository.dart';

/// 마이(아바타) 진입 시 온보딩을 자동으로 띄울지에 대한 메모리 캐시.
///
/// 매번 서버에 물어보면 아바타 버튼이 응답(최대 수 초)까지 막힌다. 그래서
/// 로그인 직후·앱 시작 시 백그라운드로 채워 두고, 진입 시에는 캐시만 본다.
/// 캐시가 비어 있으면(모름) 진입을 막지 않고 다음을 위해 뒤에서 채운다.
class ProfileOnboardingCache {
  static bool? _needsOnboarding;

  static bool? get needsOnboarding => _needsOnboarding;

  /// 캐시만으로 즉시 답한다 — 서버를 기다리지 않는다.
  static bool get shouldAutoShow =>
      AuthSession.isLoggedIn && _needsOnboarding == true;

  /// 로그인 직후·앱 시작 시 백그라운드로 부른다.
  /// 실패하면 모름(null)으로 남는다 — 마이 진입을 막는 근거가 될 수 없다.
  static Future<void> refresh({UserProfileRepository? repository}) async {
    try {
      final repo =
          repository ??
          UserProfileRepository(requestTimeout: const Duration(seconds: 3));
      _needsOnboarding = await repo.needsOnboarding();
    } on Object {
      // 모름 상태 유지.
    }
  }

  /// 온보딩을 보여줬다(입력이든 건너뛰기든). 다시 자동으로 띄우지 않는다.
  static void markAsked() => _needsOnboarding = false;

  /// 로그아웃 시.
  static void clear() => _needsOnboarding = null;

  /// 테스트 전용.
  static void debugSet(bool? value) => _needsOnboarding = value;
}
