import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/recommendation/data/recommendation_api.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

final class _NoPendingReviewDraftStore implements PendingReviewDraftGateway {
  const _NoPendingReviewDraftStore();

  @override
  Future<void> clear() async {}

  @override
  Future<PendingReviewDraft?> load() async => null;

  @override
  Future<void> save(PendingReviewDraft draft) async {}
}

class _CountingRecommendationDataSource implements RecommendationDataSource {
  var calls = 0;

  @override
  Future<NextCookRecommendationResponse> findForRecipe(String recipeId) async {
    calls += 1;
    return NextCookRecommendationResponse(
      recipeId: recipeId,
      generatedAt: DateTime.utc(2026, 8, 20),
      recommendations: const [],
    );
  }

  @override
  Future<void> recordFeedback({
    required String recipeId,
    required NextCookRecommendation recommendation,
    required RecommendationDecision decision,
    double? appliedAmount,
  }) async {}
}

Recipe _recipe() => const Recipe(
  id: '10000000-0000-0000-0000-000000000001',
  title: '계란볶음밥',
  description: '기본 레시피',
  baseServings: 1,
  imageUrl: '',
  hasPersonalVersion: false,
  latestPersonalVersionId: null,
  ingredients: [
    Ingredient(
      originalIngredientId: '20000000-0000-0000-0000-000000000501',
      name: '밥',
      amount: 1,
      unit: '공기',
      isRequired: true,
    ),
  ],
  steps: [
    CookStep(
      stepIndex: 0,
      instruction: '볶는다',
      timerSeconds: null,
      cautionNote: null,
      imageUrl: '',
    ),
  ],
);

void main() {
  testWidgets('게스트 조리 설정은 추천 대신 로그인 안내를 보여주고 API를 부르지 않는다', (tester) async {
    resetAuthForTest();
    final dataSource = _CountingRecommendationDataSource();

    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          recommendationDataSource: dataSource,
          pendingReviewDraftStore: const _NoPendingReviewDraftStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('cook-setup-guest-recommendation')),
      findsOneWidget,
    );
    expect(find.text('로그인하면 맞춤 추천이 나와요'), findsOneWidget);
    expect(dataSource.calls, 0);
  });

  testWidgets('로그인 상태면 추천을 조회한다', (tester) async {
    await signInForTest();
    final dataSource = _CountingRecommendationDataSource();

    await tester.pumpWidget(
      MaterialApp(
        home: CookSetupScreen(
          recipe: _recipe(),
          recommendationDataSource: dataSource,
          pendingReviewDraftStore: const _NoPendingReviewDraftStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('cook-setup-guest-recommendation')),
      findsNothing,
    );
    expect(dataSource.calls, 1);
  });
}
