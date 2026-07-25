import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const recipeId = '10000000-0000-0000-0000-000000000001';
  const userId = '90000000-0000-0000-0000-000000000001';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자 1', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('목록 응답에서 레시피 요약과 개인 버전 여부를 읽는다', () async {
    final repository = RecipeRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/v1/recipes');
        expect(request.headers[cookPilotUserIdHeader], userId);
        return _jsonResponse('''
          [
            {
              "id": "$recipeId",
              "title": "라면",
              "description": "기본 라면",
              "imageUrl": null,
              "hasPersonalVersion": true,
              "latestPersonalVersionId": "20000000-0000-0000-0000-000000000001"
            }
          ]
        ''');
      }),
    );

    final recipes = await repository.findAll();

    expect(recipes, hasLength(1));
    expect(recipes.single.title, '라면');
    expect(recipes.single.imageUrl, isEmpty);
    expect(recipes.single.hasPersonalVersion, isTrue);
  });

  test('상세 응답에서 재료와 조리 단계를 화면 모델로 변환한다', () async {
    const summary = RecipeSummary(
      id: recipeId,
      title: '라면',
      description: '기본 라면',
      imageUrl: '',
      hasPersonalVersion: false,
      latestPersonalVersionId: null,
    );
    final repository = RecipeRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/v1/recipes/$recipeId');
        return _jsonResponse('''
          {
            "id": "$recipeId",
            "title": "라면",
            "description": "기본 라면",
            "baseServings": 1.0,
            "imageUrl": null,
            "ingredients": [
              {"name": "물", "amount": 500.0, "unit": "ml", "required": true}
            ],
            "steps": [
              {
                "stepIndex": 0,
                "instruction": "물을 끓이세요.",
                "timerSeconds": 90,
                "cautionNote": "화상 주의",
                "imageUrl": null
              },
              {
                "stepIndex": 1,
                "instruction": "면을 넣으세요.",
                "timerSeconds": null,
                "cautionNote": null,
                "imageUrl": null
              }
            ]
          }
        ''');
      }),
    );

    final recipe = await repository.findById(summary);

    expect(recipe.id, recipeId);
    expect(recipe.baseServings, 1);
    expect(recipe.ingredients.single.amountLabel, '500ml');
    expect(recipe.steps, hasLength(2));
    expect(recipe.steps.first.timerDuration, const Duration(seconds: 90));
    expect(recipe.steps.first.minutes, 2);
    expect(recipe.steps.first.description, contains('화상 주의'));
    expect(recipe.timerMinutes, 2);
  });

  test('상세 응답 ID가 요청한 레시피와 다르면 거부한다', () async {
    const summary = RecipeSummary(
      id: recipeId,
      title: '라면',
      description: '기본 라면',
      imageUrl: '',
      hasPersonalVersion: false,
      latestPersonalVersionId: null,
    );
    final repository = RecipeRepository(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('''
          {
            "id": "10000000-0000-0000-0000-000000000099",
            "title": "다른 레시피",
            "ingredients": [
              {
                "name": "물",
                "amount": 500,
                "unit": "ml",
                "required": true
              }
            ],
            "steps": [
              {
                "stepIndex": 0,
                "instruction": "물을 끓이세요.",
                "timerSeconds": 90,
                "cautionNote": null,
                "imageUrl": null
              }
            ]
          }
        '''),
      ),
    );

    await expectLater(
      repository.findById(summary),
      throwsA(
        isA<RecipeApiException>().having(
          (exception) => exception.message,
          'message',
          contains('다른 상세 응답'),
        ),
      ),
    );
  });

  test('서버 오류 상태는 RecipeApiException으로 전달한다', () async {
    final repository = RecipeRepository(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('error', 500)),
    );

    expect(repository.findAll(), throwsA(isA<RecipeApiException>()));
  });
}

http.Response _jsonResponse(String body) {
  return http.Response(
    body,
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
