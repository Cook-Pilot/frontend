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
}
