import 'dart:convert';

import 'package:cookpilot/features/recommendation/data/recommendation_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000005';
  const ingredientId = '20000000-0000-0000-0000-000000000504';
  const recommendationId = '70000000-0000-0000-0000-000000000001';
  const reviewId = '60000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('추천과 근거를 읽고 수정 수락 피드백을 전송한다', () async {
    Map<String, dynamic>? feedbackBody;
    final repository = RecommendationRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.headers[cookPilotUserIdHeader], userId);
        if (request.method == 'GET') {
          expect(
            request.url.path,
            '/api/v1/recipes/$recipeId/next-cook-recommendations',
          );
          return _jsonResponse('''
            {
              "recipeId": "$recipeId",
              "generatedAt": "2026-07-26T10:00:00Z",
              "recommendations": [{
                "recommendationId": "$recommendationId",
                "type": "INGREDIENT_AMOUNT",
                "originalIngredientId": "$ingredientId",
                "ingredientName": "진간장",
                "originalAmount": 0.5,
                "suggestedAmount": 0.4,
                "unit": "큰술",
                "changePercent": -20,
                "confidence": 0.82,
                "reason": "최근 기록을 바탕으로 진간장을 줄여보세요.",
                "explanationSource": "FALLBACK",
                "model": null,
                "promptVersion": "f11-reason-v1",
                "evidence": [{
                  "reviewId": "$reviewId",
                  "recipeId": "10000000-0000-0000-0000-000000000003",
                  "recipeTitle": "두부조림",
                  "cookedAt": "2026-07-25T10:00:00Z",
                  "rating": 5
                }]
              }]
            }
          ''');
        }

        expect(request.method, 'PUT');
        expect(
          request.url.path,
          '/api/v1/recipes/$recipeId/recommendation-feedback/'
          '$recommendationId',
        );
        feedbackBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse('''
          {
            "id": "80000000-0000-0000-0000-000000000001",
            "recommendationId": "$recommendationId",
            "recipeId": "$recipeId",
            "originalIngredientId": "$ingredientId",
            "decision": "MODIFIED",
            "appliedAmount": 0.35,
            "createdAt": "2026-07-26T10:01:00Z"
          }
        ''');
      }),
    );

    final result = await repository.findForRecipe(recipeId);
    final recommendation = result.recommendations.single;
    expect(recommendation.ingredientName, '진간장');
    expect(recommendation.suggestedAmount, 0.4);
    expect(recommendation.evidence.single.recipeTitle, '두부조림');

    await repository.recordFeedback(
      recipeId: recipeId,
      recommendation: recommendation,
      decision: RecommendationDecision.modified,
      appliedAmount: 0.35,
    );

    expect(feedbackBody!['decision'], 'MODIFIED');
    expect(feedbackBody!['appliedAmount'], 0.35);
    expect(feedbackBody!['evidenceReviewIds'], [reviewId]);
  });

  test('추천 배열 항목 형식이 잘못되면 API 예외로 변환한다', () async {
    final repository = RecommendationRepository(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('''
          {
            "recipeId": "$recipeId",
            "generatedAt": "2026-07-26T10:00:00Z",
            "recommendations": ["잘못된 항목"]
          }
        '''),
      ),
    );

    await expectLater(
      repository.findForRecipe(recipeId),
      throwsA(isA<RecommendationApiException>()),
    );
  });
}

http.Response _jsonResponse(String body) {
  return http.Response(
    body,
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
