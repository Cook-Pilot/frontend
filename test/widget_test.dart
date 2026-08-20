import 'package:cookpilot/app/cookpilot_app.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders CookPilot app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CookPilotApp());

    // 게스트 우선: 첫 화면은 로그인이 아니라 홈 셸이다.
    expect(find.byType(MainShell), findsOneWidget);
  });
}
