import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/mvp/mock_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('팀 레시피를 새 조리 가이드 화면에 연결한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: const CookSessionScreen(recipe: tofuRecipe, servings: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('두부 조림 · 2인분'), findsOneWidget);
    expect(find.text('두부 손질'), findsOneWidget);
    expect(find.byKey(const Key('next-step')), findsOneWidget);
    expect(find.byKey(const Key('complete-session')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('조리 완료 확인 뒤 기존 리뷰 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: const CookSessionScreen(recipe: tofuRecipe, servings: 2),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('complete-session')));
    await tester.pumpAndSettle();
    expect(find.text('조리를 완료할까요?'), findsOneWidget);

    await tester.tap(find.text('완료하기'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.text('조리 완료! 어땠나요?'), findsOneWidget);
  });
}
