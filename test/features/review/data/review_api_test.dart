import 'dart:convert';

import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
import 'package:cookpilot/features/user/data/beta_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000001';
  const ingredientId = '11000000-0000-0000-0000-000000000001';
  const stepId = '12000000-0000-0000-0000-000000000001';
  const sessionId = '40000000-0000-0000-0000-000000000001';

  final snapshot = CookingSetupSnapshot(
    recipeId: recipeId,
    title: '라면',
    description: '',
    imageUrl: '',
    baseServings: 1,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: const [
      CookingSetupIngredient(
        originalIngredientId: ingredientId,
        originalName: '계란',
        name: '두부',
        amount: 2,
        baselineAmount: 2,
        unit: '개',
        isRequired: false,
      ),
    ],
    steps: const [
      CookingSetupStep(
        originalStepId: stepId,
        stepIndex: 0,
        instruction: '2분간 끓이세요.',
        timerSeconds: 120,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
  );

  setUp(() {
    BetaUserSession.setCurrentUser(
      const BetaUser(id: userId, displayName: '베타 사용자 1', betaNumber: 1),
    );
  });

  tearDown(BetaUserSession.clear);

  test('PR 37 후기 사실만 저장하고 실행 diff는 개인 버전 요청으로 분리한다', () async {
    late Map<String, dynamic> requestBody;
    final repository = ReviewRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '$baseUrl/api/v1/reviews');
        expect(request.headers[cookPilotUserIdHeader], userId);
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse(
          '{"id":"50000000-0000-0000-0000-000000000001",'
          '"createdPersonalVersionId":null}',
          statusCode: 201,
        );
      }),
    );

    final result = await repository.submit(
      clientSessionId: sessionId,
      cookedAt: DateTime.utc(2026, 7, 26, 1),
      snapshot: snapshot,
      rating: 5,
      comment: ' 맛있었어요 ',
      nextTimeNote: '  ',
    );

    expect(requestBody['clientSessionId'], sessionId);
    expect(requestBody['recipeId'], recipeId);
    expect(requestBody['targetServings'], 2);
    expect(requestBody['comment'], '맛있었어요');
    expect(requestBody['nextTimeNote'], isNull);
    expect(requestBody, isNot(contains('ingredients')));
    expect(requestBody, isNot(contains('steps')));
    // 사진이 없으면 photoUrls 필드 자체를 보내지 않는다(선택 필드 계약).
    expect(requestBody, isNot(contains('photoUrls')));
    expect(result.createdPersonalVersionId, isNull);
  });

  test('업로드된 사진 URL을 순서 그대로 photoUrls로 보낸다', () async {
    late Map<String, dynamic> requestBody;
    final repository = ReviewRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse(
          '{"id":"50000000-0000-0000-0000-000000000001",'
          '"createdPersonalVersionId":null}',
          statusCode: 201,
        );
      }),
    );

    await repository.submit(
      clientSessionId: sessionId,
      cookedAt: DateTime.utc(2026, 7, 26, 1),
      snapshot: snapshot,
      rating: 5,
      comment: '맛있었어요',
      nextTimeNote: '',
      photoUrls: const [
        'https://cdn.example.test/b.jpg',
        'https://cdn.example.test/a.jpg',
      ],
    );

    expect(requestBody['photoUrls'], [
      'https://cdn.example.test/b.jpg',
      'https://cdn.example.test/a.jpg',
    ]);
  });

  test('월 범위를 UTC 쿼리로 보내고 조리 이력을 읽는다', () async {
    // 로컬 타임존과 무관하게 통과하도록 기대값을 입력에서 파생시킨다.
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 8, 1);
    final repository = ReviewRepository(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/cooking-history');
        expect(
          request.url.queryParameters['from'],
          from.toUtc().toIso8601String(),
        );
        expect(request.url.queryParameters['to'], to.toUtc().toIso8601String());
        expect(request.headers[cookPilotUserIdHeader], userId);
        return _jsonResponse('''
          [
            {
              "reviewId": "50000000-0000-0000-0000-000000000001",
              "recipeId": "$recipeId",
              "recipeTitle": "라면",
              "recipeImageUrl": null,
              "cookedAt": "2026-07-26T01:00:00Z",
              "rating": 5,
              "comment": "맛있었어요",
              "nextTimeNote": "물은 조금 적게",
              "sourcePersonalVersionId": null,
              "createdPersonalVersionId":
                "20000000-0000-0000-0000-000000000001",
              "createdPersonalVersionNumber": 2,
              "createdPersonalVersionSummary": "물 양 조정"
            }
          ]
        ''');
      }),
    );

    final history = await repository.findHistory(from: from, to: to);

    expect(history, hasLength(1));
    expect(history.single.recipeTitle, '라면');
    expect(history.single.rating, 5);
    expect(history.single.createdPersonalVersionNumber, 2);
    expect(history.single.cookedAt.toUtc(), DateTime.utc(2026, 7, 26, 1));
  });

  test('사용자 세션이 없으면 후기 HTTP 요청을 보내지 않는다', () async {
    BetaUserSession.clear();
    var requestCount = 0;
    final repository = ReviewRepository(
      baseUrl: baseUrl,
      client: MockClient((_) async {
        requestCount++;
        return _jsonResponse('{}');
      }),
    );

    await expectLater(
      repository.submit(
        clientSessionId: sessionId,
        cookedAt: DateTime.utc(2026, 7, 26),
        snapshot: snapshot,
        rating: 5,
        comment: '',
        nextTimeNote: '',
      ),
      throwsA(isA<BetaUserException>()),
    );
    expect(requestCount, 0);
  });

  test('조리 이력의 선택 필드 타입이 잘못되면 API 예외로 통일한다', () async {
    final repository = ReviewRepository(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => _jsonResponse('''
          [
            {
              "reviewId": "50000000-0000-0000-0000-000000000001",
              "recipeId": "$recipeId",
              "recipeTitle": "라면",
              "cookedAt": "2026-07-26T01:00:00Z",
              "rating": "별 다섯"
            }
          ]
        '''),
      ),
    );

    await expectLater(
      repository.findHistory(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 8, 1),
      ),
      throwsA(isA<ReviewApiException>()),
    );
  });
}

http.Response _jsonResponse(String body, {int statusCode = 200}) {
  return http.Response(
    body,
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
