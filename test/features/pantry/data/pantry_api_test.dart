import 'dart:convert';

import 'package:cookpilot/features/pantry/data/pantry_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const itemId = '70000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000003';

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('카탈로그·보유 재료·추천을 읽고 재료를 담고 삭제한다', () async {
    Map<String, dynamic>? addBody;
    var deleteCalled = false;
    final repository = PantryRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.headers[cookPilotUserIdHeader], userId);

        if (request.method == 'GET' &&
            request.url.path == '/api/v1/pantry/ingredient-catalog') {
          return _jsonResponse('''
            [{"name": "계란", "emoji": "🥚", "defaultShelfLifeDays": 21}]
          ''');
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/pantry/items') {
          return _jsonResponse('''
            [{
              "id": "$itemId",
              "ingredientName": "계란",
              "emoji": "🥚",
              "useByDate": "2026-08-01",
              "daysUntilExpiry": 5
            }]
          ''');
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/pantry/recipe-suggestions') {
          return _jsonResponse('''
            {
              "generatedAt": "2026-07-27T00:00:00Z",
              "suggestions": [{
                "recipeId": "$recipeId",
                "recipeTitle": "두부조림",
                "recipeImageUrl": "https://example.test/tofu.png",
                "matchedIngredients": [{
                  "ingredientName": "두부",
                  "emoji": "⬜",
                  "daysUntilExpiry": 1
                }],
                "mostUrgentDaysUntilExpiry": 1
              }]
            }
          ''');
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/pantry/items') {
          addBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '''
              {
                "id": "$itemId",
                "ingredientName": "계란",
                "emoji": "🥚",
                "useByDate": "2026-08-10",
                "daysUntilExpiry": 14
              }
            ''',
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/pantry/items/$itemId') {
          deleteCalled = true;
          return http.Response('', 204);
        }
        throw StateError('예상하지 못한 요청: ${request.method} ${request.url}');
      }),
    );

    final catalog = await repository.findCatalog();
    expect(catalog.single.name, '계란');
    expect(catalog.single.emoji, '🥚');

    final items = await repository.findItems();
    expect(items.single.ingredientName, '계란');
    expect(items.single.daysUntilExpiry, 5);

    final suggestions = await repository.findRecipeSuggestions();
    expect(suggestions.single.recipeTitle, '두부조림');
    expect(suggestions.single.matchedIngredients.single.ingredientName, '두부');
    expect(suggestions.single.mostUrgentDaysUntilExpiry, 1);

    final added = await repository.addItem('계란');
    expect(added.daysUntilExpiry, 14);
    expect(addBody!['ingredientName'], '계란');

    await repository.removeItem(itemId);
    expect(deleteCalled, isTrue);
  });

  test('추천 목록 항목 형식이 잘못되면 API 예외로 변환한다', () async {
    final repository = PantryRepository(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('''
          {
            "generatedAt": "2026-07-27T00:00:00Z",
            "suggestions": ["잘못된 항목"]
          }
        '''),
      ),
    );

    await expectLater(
      repository.findRecipeSuggestions(),
      throwsA(isA<PantryApiException>()),
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
