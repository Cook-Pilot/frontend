import 'dart:async';

import 'package:cookpilot/app/cooklog_mark.dart';
import 'package:cookpilot/app/cookpilot_app.dart';
import 'package:cookpilot/features/mvp/auth_screen.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱은 세션 여부와 무관하게 홈으로 시작한다', (tester) async {
    await tester.pumpWidget(const CookPilotApp());
    await tester.pump();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('준비 작업 동안 랜딩 화면을 보여 주고 끝나면 홈으로 넘어간다', (tester) async {
    final startup = Completer<void>();

    await tester.pumpWidget(CookPilotApp(startup: startup.future));
    await tester.pump();

    expect(find.byType(CookLogLanding), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);

    startup.complete();
    // 준비가 곧바로 끝나도 로고는 최소 시간만큼 머무른다.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CookLogLanding), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(CookLogLanding), findsNothing);
  });
}
