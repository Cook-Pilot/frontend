import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const recipe = Recipe(
    id: '10000000-0000-0000-0000-000000000003',
    title: '앱바 테스트 레시피',
    description: '조리 중 화면 앱바를 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '물을 끓이세요.',
        timerSeconds: 180,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('조리 중 화면 앱바에는 나가기 버튼만 두고 일시정지 버튼은 두지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CookSessionScreen(
          recipe: recipe,
          servings: 2,
          alarm: SilentTimerAlarm(),
        ),
      ),
    );
    await tester.pump();

    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.close_rounded)),
      findsOneWidget,
    );
    // 타이머 일시정지는 본문 버튼이, 세션 중단은 나가기 버튼이 담당한다.
    // 앱바에 동작 없는 일시정지 버튼을 다시 두지 않는다.
    expect(
      find.descendant(of: appBar, matching: find.byIcon(Icons.pause_rounded)),
      findsNothing,
    );
  });
}
