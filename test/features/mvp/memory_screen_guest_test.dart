import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  testWidgets('게스트 메모리 탭은 기록 대신 로그인 안내를 보여준다', (tester) async {
    resetAuthForTest();

    await tester.pumpWidget(
      MaterialApp(home: MemoryScreen(initialDate: DateTime(2026, 8, 19))),
    );
    await tester.pump();

    expect(find.text('로그인하면 조리 기록이 여기 모여요'), findsOneWidget);
    expect(find.byKey(const Key('memory-login-button')), findsOneWidget);
    // 달력(월 이동 헤더)은 게스트에게 보이지 않는다.
    expect(find.text('2026년 8월'), findsNothing);
  });
}
