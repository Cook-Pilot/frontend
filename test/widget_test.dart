import 'package:cookpilot/app/cookpilot_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders CookPilot app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CookPilotApp());

    expect(find.text('CookPilot'), findsOneWidget);
    expect(find.text('게스트로 둘러보기'), findsOneWidget);
  });
}
