import 'package:cookpilot/features/mvp/mvp_widgets.dart';
import 'package:cookpilot/features/mvp/shell_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => shellTabIndex.value = shellHomeTab);

  testWidgets('로고를 누르면 루트로 돌아가고 홈 탭까지 간다', (tester) async {
    // 검색 탭에서 상세로 들어간 상황을 만든다.
    shellTabIndex.value = shellSearchTab;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PageShell(
                      homeLogo: true,
                      title: '레시피 상세',
                      children: [Text('본문')],
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('레시피 상세'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-logo')));
    await tester.pumpAndSettle();

    // 루트로 돌아왔고,
    expect(find.text('레시피 상세'), findsNothing);
    expect(find.text('열기'), findsOneWidget);
    // 탭도 홈으로 바뀌었다 — 둘 중 하나만 하면 '검색 탭의 루트'에 남는다.
    expect(shellTabIndex.value, shellHomeTab);
  });

  testWidgets('homeLogo 를 켜지 않으면 로고가 없다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PageShell(title: '설정', children: [Text('본문')]),
      ),
    );

    expect(find.byKey(const Key('home-logo')), findsNothing);
  });
}
