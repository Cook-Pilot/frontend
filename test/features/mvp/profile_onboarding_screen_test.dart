import 'dart:convert';

import 'package:cookpilot/features/mvp/profile_onboarding_screen.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:cookpilot/features/user/data/user_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자 1', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  // 화면을 띄우고, PATCH로 전송된 body들을 기록해 돌려준다.
  Future<List<Object?>> pumpScreen(WidgetTester tester) async {
    final bodies = <Object?>[];
    final repository = UserProfileRepository(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        bodies.add(jsonDecode(request.body));
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: ProfileOnboardingScreen(repository: repository)),
    );
    return bodies;
  }

  testWidgets('선택 전엔 확인이 비활성, 하나만 골라도 고른 값만 전송한다', (tester) async {
    final bodies = await pumpScreen(tester);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('여성'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(bodies, [
      {'gender': 'F'},
    ]);
  });

  testWidgets('건너뛰기는 빈 body를 보낸다', (tester) async {
    final bodies = await pumpScreen(tester);

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();

    expect(bodies, [<String, dynamic>{}]);
  });
}
