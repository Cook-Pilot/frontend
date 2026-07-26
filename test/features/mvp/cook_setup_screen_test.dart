import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const userId = '90000000-0000-0000-0000-000000000001';
  const versionId = '20000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  testWidgets('최신 개인 버전을 불러와 이번 조리의 기본 선택으로 사용한다', (tester) async {
    final repository = RecipeRepository(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/personal-versions/$versionId');
        return http.Response(
          '''
          {
            "version": {
              "id": "$versionId",
              "title": "간장을 줄인 계란볶음밥 v1",
              "summary": "간장 20% 감소"
            },
            "ingredients": [
              {
                "originalIngredientId": null,
                "name": "밥",
                "amount": 0.8,
                "unit": "공기",
                "required": true,
                "origin": "MODIFIED"
              }
            ],
            "steps": [
              {
                "stepIndex": 0,
                "originalStepId": null,
                "instruction": "볶으세요.",
                "timerSeconds": 60,
                "cautionNote": null,
                "origin": "ORIGINAL"
              }
            ],
            "ingredientAdjustments": [],
            "stepAdjustments": []
          }
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(
            hasPersonalVersion: true,
            latestPersonalVersionId: versionId,
          ),
          recipeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('간장을 줄인 계란볶음밥 v1'), findsOneWidget);
    expect(find.text('간장 20% 감소'), findsOneWidget);
    expect(find.text('0.8공기'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('1인분 · 나 맞춤'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    await tester.tap(find.text('기본'));
    await tester.pump();

    expect(find.text('1공기'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('1인분 · 기본'), findsOneWidget);
  });

  testWidgets('인분을 변경하면 현재 재료 양을 같은 비율로 조정한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          sessionAlarm: const SilentTimerAlarm(),
        ),
      ),
    );

    expect(find.text('1공기'), findsOneWidget);
    expect(find.text('2개'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();

    expect(find.text('2인분'), findsOneWidget);
    expect(find.text('2공기'), findsOneWidget);
    expect(find.text('4개'), findsOneWidget);
  });

  testWidgets('재료 양 조절 결과를 조리 시작 스냅샷에 고정한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          sessionAlarm: const SilentTimerAlarm(),
        ),
      ),
    );

    await tester.tap(find.text('수정').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.ensureVisible(find.text('적용'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('1.5공기'), findsOneWidget);

    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    final session = tester.widget<CookSessionScreen>(
      find.byType(CookSessionScreen),
    );
    expect(session.setupSnapshot, isNotNull);
    expect(session.setupSnapshot!.ingredients.first.amount, 1.5);
    expect(session.recipe.ingredients.first.amount, 1.5);
  });

  testWidgets('재료를 직접 입력한 다른 재료로 대체할 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CookSetupScreen(recipe: _recipe())),
    );

    await tester.tap(find.text('수정').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대체'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '두부');
    await tester.ensureVisible(find.text('적용'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('두부'), findsOneWidget);
    expect(find.text('대체'), findsOneWidget);
  });

  testWidgets('대체한 재료를 기본 재료로 되돌릴 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          sessionAlarm: const SilentTimerAlarm(),
        ),
      ),
    );

    await tester.tap(find.text('수정').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.tap(find.text('대체'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '두부');
    await tester.ensureVisible(find.text('적용'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('수정').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본 재료(계란)로 되돌리기'));
    await tester.pumpAndSettle();

    expect(find.text('계란'), findsOneWidget);
    expect(find.text('대체'), findsNothing);

    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    final session = tester.widget<CookSessionScreen>(
      find.byType(CookSessionScreen),
    );
    final restoredIngredient = session.setupSnapshot!.ingredients[1];
    expect(restoredIngredient.name, '계란');
    expect(restoredIngredient.amount, 2);
    expect(restoredIngredient.isSubstituted, isFalse);
  });

  testWidgets('기준 인분이 잘못된 레시피도 유효한 실행 스냅샷으로 보정한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(baseServings: 0),
          sessionAlarm: const SilentTimerAlarm(),
        ),
      ),
    );

    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    final session = tester.widget<CookSessionScreen>(
      find.byType(CookSessionScreen),
    );
    expect(session.setupSnapshot, isNotNull);
    expect(session.setupSnapshot!.baseServings, 1);
    expect(session.setupSnapshot!.targetServings, 1);
  });

  testWidgets('필수 재료도 경고를 확인한 뒤 이번 조리에서 생략할 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CookSetupScreen(recipe: _recipe())),
    );

    await tester.tap(find.text('수정').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('생략'));
    await tester.pump();

    expect(find.text('필수 재료를 생략할까요?'), findsOneWidget);

    await tester.ensureVisible(find.text('적용'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();

    expect(find.text('이번 조리에서 생략'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.textContaining('생략 1개'), findsOneWidget);
  });
}

Recipe _recipe({
  bool hasPersonalVersion = false,
  String? latestPersonalVersionId,
  double baseServings = 1,
}) {
  return Recipe(
    id: '10000000-0000-0000-0000-000000000001',
    title: '계란볶음밥',
    description: '기본 레시피',
    baseServings: baseServings,
    imageUrl: '',
    ingredients: const [
      Ingredient(name: '밥', amount: 1, unit: '공기', isRequired: true),
      Ingredient(name: '계란', amount: 2, unit: '개', isRequired: true),
    ],
    steps: const [
      CookStep(
        stepIndex: 0,
        instruction: '볶으세요.',
        timerSeconds: 60,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: hasPersonalVersion,
    latestPersonalVersionId: latestPersonalVersionId,
  );
}
