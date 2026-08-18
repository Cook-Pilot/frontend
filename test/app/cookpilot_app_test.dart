import 'package:cookpilot/app/cookpilot_app.dart';
import 'package:cookpilot/features/mvp/auth_screen.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('세션을 복원하면 로그인 화면을 건너뛴다', (tester) async {
    await tester.pumpWidget(const CookPilotApp(startLoggedIn: true));
    await tester.pump();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });

  testWidgets('세션이 없으면 로그인 화면으로 시작한다', (tester) async {
    await tester.pumpWidget(const CookPilotApp());
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
  });
}
