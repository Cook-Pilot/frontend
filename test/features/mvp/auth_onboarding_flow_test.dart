import 'package:cookpilot/features/mvp/auth_screen.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/mvp/profile_onboarding_screen.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:cookpilot/features/user/data/user_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 세션에 사용자가 있으면 ensureUser가 네트워크 없이 바로 끝난다.
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자 1', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  // 로그인 버튼을 눌러 _openHome의 온보딩 분기까지 진행시킨다.
  Future<void> pumpAndLogin(
    WidgetTester tester,
    Future<http.Response> Function(http.Request request) respond,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          profileRepository: UserProfileRepository(
            baseUrl: 'http://example.test',
            client: MockClient(respond),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('profileAskedAt이 null이면 온보딩 화면으로 간다', (tester) async {
    await pumpAndLogin(
      tester,
      (_) async => http.Response('{"profileAskedAt": null}', 200),
    );

    expect(find.byType(ProfileOnboardingScreen), findsOneWidget);
  });

  testWidgets('이미 물어본 사용자는 메인으로 간다', (tester) async {
    await pumpAndLogin(
      tester,
      (_) async =>
          http.Response('{"profileAskedAt": "2026-08-18T00:00:00Z"}', 200),
    );

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(ProfileOnboardingScreen), findsNothing);
  });

  testWidgets('프로필 조회가 실패해도 메인 진입을 막지 않는다', (tester) async {
    await pumpAndLogin(tester, (_) async => http.Response('boom', 500));

    expect(find.byType(MainShell), findsOneWidget);
  });
}
