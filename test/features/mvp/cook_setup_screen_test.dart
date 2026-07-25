import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('개인 버전은 존재만 안내하고 원본 레시피를 선택 상태로 표시한다', (tester) async {
    const recipe = Recipe(
      id: '10000000-0000-0000-0000-000000000001',
      title: '김치볶음밥',
      description: '기본 레시피',
      baseServings: 1,
      imageUrl: '',
      ingredients: <Ingredient>[],
      steps: <CookStep>[],
      hasPersonalVersion: true,
      latestPersonalVersionId: '20000000-0000-0000-0000-000000000001',
    );

    await tester.pumpWidget(
      const MaterialApp(home: CookSetupScreen(recipe: recipe)),
    );

    expect(find.text('기본'), findsOneWidget);
    expect(find.text('나 맞춤 버전 있음'), findsOneWidget);
    expect(find.text('이 레시피의 나 맞춤 버전이 있어요'), findsOneWidget);
    expect(find.text('이번 조리는 원본 레시피로 진행해요.'), findsOneWidget);
    expect(find.text('1인분 · 기본'), findsOneWidget);
  });
}
