import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/recommendation/data/recommendation_api.dart';
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

  testWidgets('최근 개인 버전을 보여주고 사용자가 선택한 뒤 적용한다', (tester) async {
    final repository = RecipeRepository(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/personal-versions')) {
          return http.Response(
            '''
            [{
              "id": "$versionId",
              "recipeId": "10000000-0000-0000-0000-000000000001",
              "versionNumber": 1,
              "title": "간장을 줄인 계란볶음밥 v1",
              "summary": "간장 20% 감소",
              "createdAt": "2026-07-26T01:00:00Z"
            }]
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(request.url.path, '/api/v1/personal-versions/$versionId');
        return http.Response(
          '''
          {
            "version": {
              "id": "$versionId",
              "versionNumber": 1,
              "title": "간장을 줄인 계란볶음밥 v1",
              "summary": "간장 20% 감소",
              "createdAt": "2026-07-26T01:00:00Z"
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

    expect(find.text('기본 레시피'), findsOneWidget);
    expect(find.text('1공기'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);

    await tester.tap(find.text('v1'));
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

  testWidgets('다른 개인 버전 로딩에 실패하면 기본 레시피로 되돌린다', (tester) async {
    const secondVersionId = '20000000-0000-0000-0000-000000000002';
    final repository = RecipeRepository(
      baseUrl: 'http://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/personal-versions')) {
          return http.Response(
            '''
            [
              {
                "id": "$versionId",
                "recipeId": "10000000-0000-0000-0000-000000000001",
                "versionNumber": 1,
                "title": "성공하는 개인 버전",
                "summary": "밥 양 조정",
                "createdAt": "2026-07-26T01:00:00Z"
              },
              {
                "id": "$secondVersionId",
                "recipeId": "10000000-0000-0000-0000-000000000001",
                "versionNumber": 2,
                "title": "불러오지 못할 개인 버전",
                "summary": "테스트",
                "createdAt": "2026-07-26T02:00:00Z"
              }
            ]
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path.endsWith(secondVersionId)) {
          return http.Response('{}', 500);
        }
        return http.Response(
          '''
          {
            "version": {
              "id": "$versionId",
              "versionNumber": 1,
              "title": "성공하는 개인 버전",
              "summary": "밥 양 조정",
              "createdAt": "2026-07-26T01:00:00Z"
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
            latestPersonalVersionId: secondVersionId,
          ),
          recipeRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('v1'));
    await tester.pumpAndSettle();
    expect(find.text('0.8공기'), findsOneWidget);

    await tester.tap(find.text('v2'));
    await tester.pumpAndSettle();

    expect(find.text('기본 레시피'), findsOneWidget);
    expect(find.text('1공기'), findsOneWidget);
    expect(find.text('0.8공기'), findsNothing);
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

  testWidgets('개인화 추천은 사용자가 적용한 경우에만 실행 스냅샷을 바꾼다', (tester) async {
    final recommendations = _FakeRecommendationDataSource();

    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          recommendationDataSource: recommendations,
          sessionAlarm: const SilentTimerAlarm(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('계란 25% 감소'), findsOneWidget);
    expect(find.text('2개 → 1.5개'), findsOneWidget);

    await tester.tap(find.text('이번 조리에 적용'));
    await tester.pumpAndSettle();

    expect(recommendations.lastDecision, RecommendationDecision.accepted);
    expect(recommendations.lastAppliedAmount, 1.5);

    await tester.ensureVisible(find.text('이 설정으로 조리 시작'));
    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    final session = tester.widget<CookSessionScreen>(
      find.byType(CookSessionScreen),
    );
    expect(session.setupSnapshot!.ingredients[1].amount, 1.5);
  });

  testWidgets('추천 대상 원본 재료가 다른 재료로 대체된 경우 적용하지 않는다', (tester) async {
    final recommendations = _FakeRecommendationDataSource();

    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(eggName: '메추리알'),
          recommendationDataSource: recommendations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('이번 조리에 적용'));
    await tester.pumpAndSettle();

    expect(find.textContaining('생략되거나 대체되어'), findsOneWidget);
    expect(recommendations.lastDecision, isNull);
  });
}

Recipe _recipe({
  bool hasPersonalVersion = false,
  String? latestPersonalVersionId,
  double baseServings = 1,
  String eggName = '계란',
}) {
  return Recipe(
    id: '10000000-0000-0000-0000-000000000001',
    title: '계란볶음밥',
    description: '기본 레시피',
    baseServings: baseServings,
    imageUrl: '',
    ingredients: [
      const Ingredient(
        originalIngredientId: '20000000-0000-0000-0000-000000000501',
        name: '밥',
        amount: 1,
        unit: '공기',
        isRequired: true,
      ),
      Ingredient(
        originalIngredientId: '20000000-0000-0000-0000-000000000502',
        name: eggName,
        amount: 2,
        unit: '개',
        isRequired: true,
      ),
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

final class _FakeRecommendationDataSource implements RecommendationDataSource {
  RecommendationDecision? lastDecision;
  double? lastAppliedAmount;

  @override
  Future<NextCookRecommendationResponse> findForRecipe(String recipeId) async {
    return NextCookRecommendationResponse(
      recipeId: recipeId,
      generatedAt: DateTime.utc(2026, 7, 26),
      recommendations: [
        NextCookRecommendation(
          recommendationId: '70000000-0000-0000-0000-000000000001',
          type: 'INGREDIENT_AMOUNT',
          originalIngredientId: '20000000-0000-0000-0000-000000000502',
          ingredientName: '계란',
          originalAmount: 2,
          suggestedAmount: 1.5,
          unit: '개',
          changePercent: -25,
          confidence: 0.8,
          reason: '최근 만족도 높은 기록에서 계란을 적게 사용했어요.',
          explanationSource: 'FALLBACK',
          model: null,
          promptVersion: 'f11-reason-v1',
          evidence: [
            RecommendationEvidence(
              reviewId: '60000000-0000-0000-0000-000000000001',
              recipeId: '10000000-0000-0000-0000-000000000002',
              recipeTitle: '김치볶음밥',
              cookedAt: DateTime.utc(2026, 7, 25),
              rating: 5,
            ),
            RecommendationEvidence(
              reviewId: '60000000-0000-0000-0000-000000000002',
              recipeId: '10000000-0000-0000-0000-000000000003',
              recipeTitle: '두부조림',
              cookedAt: DateTime.utc(2026, 7, 24),
              rating: 4,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> recordFeedback({
    required String recipeId,
    required NextCookRecommendation recommendation,
    required RecommendationDecision decision,
    double? appliedAmount,
  }) async {
    lastDecision = decision;
    lastAppliedAmount = appliedAmount;
  }
}
