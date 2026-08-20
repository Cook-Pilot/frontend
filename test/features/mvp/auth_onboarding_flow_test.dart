import 'package:cookpilot/features/mvp/auth_screen.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/mvp/profile_onboarding_screen.dart';
import 'package:cookpilot/features/user/data/user_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  setUp(signInForTest);

  tearDown(resetAuthForTest);

  /// 로그인 직후 분기만 확인한다. 실제 화면 전환은 소셜 SDK 를 타야 해서
  /// 위젯 테스트로 몰 수 없다.
  Future<Widget> resolve(
    Future<http.Response> Function(http.Request request) respond,
  ) {
    return homeAfterLogin(
      profileRepository: UserProfileRepository(
        baseUrl: 'http://example.test',
        client: MockClient(respond),
      ),
    );
  }

  test('profileAskedAt이 null이면 온보딩 화면으로 간다', () async {
    expect(
      await resolve(
        (_) async => http.Response('{"profileAskedAt": null}', 200),
      ),
      isA<ProfileOnboardingScreen>(),
    );
  });

  test('이미 물어본 사용자는 메인으로 간다', () async {
    expect(
      await resolve(
        (_) async =>
            http.Response('{"profileAskedAt": "2026-08-18T00:00:00Z"}', 200),
      ),
      isA<MainShell>(),
    );
  });

  test('프로필 조회가 실패해도 메인 진입을 막지 않는다', () async {
    expect(
      await resolve((_) async => http.Response('boom', 500)),
      isA<MainShell>(),
    );
  });
}
