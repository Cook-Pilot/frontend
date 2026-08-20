import 'package:cookpilot/features/user/data/profile_onboarding_cache.dart';
import 'package:cookpilot/features/user/data/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

class _FakeProfileRepository extends UserProfileRepository {
  _FakeProfileRepository(this._needsOnboarding)
    : super(baseUrl: 'http://example.test');

  final bool _needsOnboarding;

  @override
  Future<bool> needsOnboarding() async => _needsOnboarding;
}

class _FailingProfileRepository extends UserProfileRepository {
  _FailingProfileRepository() : super(baseUrl: 'http://example.test');

  @override
  Future<bool> needsOnboarding() async => throw Exception('네트워크 실패');
}

void main() {
  setUp(() {
    ProfileOnboardingCache.debugSet(null);
    resetAuthForTest();
  });

  test('refresh 성공은 서버 답을 캐시에 담는다', () async {
    await ProfileOnboardingCache.refresh(
      repository: _FakeProfileRepository(true),
    );
    expect(ProfileOnboardingCache.needsOnboarding, isTrue);

    await ProfileOnboardingCache.refresh(
      repository: _FakeProfileRepository(false),
    );
    expect(ProfileOnboardingCache.needsOnboarding, isFalse);
  });

  test('refresh 실패는 모름(null)으로 남는다 — 마이 진입을 막지 않는다', () async {
    await ProfileOnboardingCache.refresh(
      repository: _FailingProfileRepository(),
    );
    expect(ProfileOnboardingCache.needsOnboarding, isNull);
  });

  test('shouldAutoShow 는 로그인 + 캐시가 참일 때만 참이다', () async {
    // 게스트면 캐시가 참이어도 자동 표시하지 않는다.
    ProfileOnboardingCache.debugSet(true);
    expect(ProfileOnboardingCache.shouldAutoShow, isFalse);

    await signInForTest();
    expect(ProfileOnboardingCache.shouldAutoShow, isTrue);

    // 모름(null)은 자동 표시 근거가 아니다.
    ProfileOnboardingCache.debugSet(null);
    expect(ProfileOnboardingCache.shouldAutoShow, isFalse);

    ProfileOnboardingCache.debugSet(true);
    ProfileOnboardingCache.markAsked();
    expect(ProfileOnboardingCache.shouldAutoShow, isFalse);

    ProfileOnboardingCache.debugSet(true);
    ProfileOnboardingCache.clear();
    expect(ProfileOnboardingCache.needsOnboarding, isNull);
  });
}
