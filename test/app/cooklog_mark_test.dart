import 'package:cookpilot/app/cooklog_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로더는 라벨과 함께 심볼을 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CookLogLoader(label: '불 올리는 중')),
      ),
    );
    await tester.pump();

    expect(find.byType(CookLogMark), findsOneWidget);
    expect(find.text('불 올리는 중'), findsOneWidget);
  });

  testWidgets('모션을 끈 사용자에게는 정지 심볼을 준다', (tester) async {
    // MediaQuery 를 직접 감싸는 대신 플랫폼 설정을 켠다 — 화면 크기 등 나머지는 그대로 둔다.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CookLogLoader())),
    );
    await tester.pump();

    // 애니메이션이 없으므로 위상도 없다 — 원본 로고 그대로다.
    final mark = tester.widget<CookLogMark>(find.byType(CookLogMark));
    expect(mark.steam, isNull);
  });

  testWidgets('심볼 기본값은 정지 상태다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CookLogMark())),
    );

    expect(tester.widget<CookLogMark>(find.byType(CookLogMark)).steam, isNull);
  });
}
