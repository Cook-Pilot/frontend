import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recipe = Recipe(
  id: '10000000-0000-0000-0000-000000000009',
  title: '스와이프 테스트 레시피',
  description: '좌우 스와이프로 단계를 넘긴다.',
  baseServings: 1,
  imageUrl: '',
  ingredients: <Ingredient>[],
  steps: <CookStep>[
    CookStep(
      stepIndex: 0,
      instruction: '재료를 손질하세요.',
      timerSeconds: null,
      cautionNote: null,
      imageUrl: '',
    ),
    CookStep(
      stepIndex: 1,
      instruction: '팬에 볶으세요.',
      timerSeconds: null,
      cautionNote: null,
      imageUrl: '',
    ),
  ],
  hasPersonalVersion: false,
);

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    const MaterialApp(
      home: CookSessionScreen(
        recipe: _recipe,
        servings: 1,
        alarm: SilentTimerAlarm(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final swipeArea = find.byKey(const Key('cook-step-swipe'));

  testWidgets('왼쪽으로 밀면 다음 단계로 간다', (tester) async {
    await _pump(tester);
    expect(find.text('1 / 2 단계'), findsOneWidget);

    await tester.fling(swipeArea, const Offset(-300, 0), 1000);
    await tester.pump();

    expect(find.text('2 / 2 단계'), findsOneWidget);
  });

  testWidgets('오른쪽으로 밀면 이전 단계로 돌아온다', (tester) async {
    await _pump(tester);
    await tester.fling(swipeArea, const Offset(-300, 0), 1000);
    await tester.pump();

    await tester.fling(swipeArea, const Offset(300, 0), 1000);
    await tester.pump();

    expect(find.text('1 / 2 단계'), findsOneWidget);
  });

  testWidgets('첫 단계에서 오른쪽으로 밀어도 그대로다', (tester) async {
    await _pump(tester);

    await tester.fling(swipeArea, const Offset(300, 0), 1000);
    await tester.pump();

    expect(find.text('1 / 2 단계'), findsOneWidget);
  });

  testWidgets('마지막 단계에서 왼쪽으로 밀어도 조리를 끝내지 않는다', (tester) async {
    // 조리 완료는 되돌리기 어려운 동작이라 스친 제스처로 끝나면 안 된다.
    await _pump(tester);
    await tester.fling(swipeArea, const Offset(-300, 0), 1000);
    await tester.pump();

    await tester.fling(swipeArea, const Offset(-300, 0), 1000);
    await tester.pump();

    expect(find.text('2 / 2 단계'), findsOneWidget);
    expect(find.text('조리 완료'), findsOneWidget);
  });

  testWidgets('살짝 스친 제스처는 무시한다', (tester) async {
    await _pump(tester);

    await tester.drag(swipeArea, const Offset(-40, 0));
    await tester.pump();

    expect(find.text('1 / 2 단계'), findsOneWidget);
  });
}
