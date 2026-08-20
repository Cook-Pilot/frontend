import 'dart:async';
import 'dart:convert';

import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/data/personal_version_approval_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  const baseUrl = 'http://example.test';
  const userId = '90000000-0000-0000-0000-000000000001';
  const recipeId = '10000000-0000-0000-0000-000000000001';
  const reviewId = '50000000-0000-0000-0000-000000000001';
  const versionId = '20000000-0000-0000-0000-000000000001';

  setUp(signInForTest);

  tearDown(resetAuthForTest);

  test('snapshot을 PR 37 setup diff로 변환하고 201 생성 marker를 반환한다', () async {
    late Map<String, dynamic> requestBody;
    final api = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          '$baseUrl/api/v1/reviews/$reviewId/personal-versions',
        );
        expect(request.headers['Authorization'], testAuthHeader);
        expect(request.headers['content-type'], 'application/json');
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse('''
            {
              "id": "$versionId",
              "userId": "$userId",
              "recipeId": "$recipeId",
              "versionNumber": 2,
              "title": "내 라면 v2",
              "summary": "물 양과 재료를 조정",
              "sourceReviewId": "$reviewId",
              "parentVersionId": null,
              "isDefault": false,
              "createdAt": null
            }
          ''', statusCode: 201);
      }),
    );

    final result = await api.createFromApprovedReview(
      reviewId: reviewId,
      snapshot: _editedSnapshot,
      cookingTranscript: '  물을 조금 더 넣었어요.  ',
    );

    final setup = requestBody['setup'] as Map<String, dynamic>;
    final adjustments = setup['ingredientAdjustments'] as List<dynamic>;
    expect(setup['stepAdjustments'], isEmpty);
    expect(adjustments, <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000002',
        'type': 'REMOVE',
        'sortOrder': 1,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000003',
        'type': 'MODIFY',
        'name': '쪽파',
        'sortOrder': 2,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000004',
        'type': 'MODIFY',
        'amount': 2.5,
        'sortOrder': 3,
      },
      <String, Object?>{
        'type': 'ADD',
        'name': '치즈',
        'amount': 1.0,
        'unit': '장',
        'required': false,
        'sortOrder': 4,
      },
    ]);
    expect(requestBody['cooking'], <String, Object?>{
      'transcript': '물을 조금 더 넣었어요.',
    });
    expect(result, isA<PersonalVersionCreated>());
  });

  test('현재 UI의 단계와 조리 중 타이머 변경은 setup step diff에 넣지 않는다', () {
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _editedSnapshot,
      cookingTranscript: null,
    ).toJson();

    final setup = request['setup'] as Map<String, Object?>;
    expect(setup['stepAdjustments'], isEmpty);
    expect(request['cooking'], <String, Object?>{'transcript': null});
  });

  test('원본 baseline이 없는 legacy 개인 버전 초안은 승인 diff 생성을 막는다', () {
    final legacyPersonalSnapshot = CookingSetupSnapshot(
      recipeId: recipeId,
      title: '내 라면 v1',
      description: '',
      imageUrl: '',
      baseServings: 1,
      targetServings: 2,
      source: CookingRecipeSource.personal,
      personalVersionId: versionId,
      ingredients: const <CookingSetupIngredient>[
        CookingSetupIngredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          originalName: '육수',
          name: '육수',
          amount: 600,
          baselineAmount: 600,
          unit: 'ml',
          isRequired: true,
        ),
      ],
      steps: const <CookingSetupStep>[
        CookingSetupStep(
          originalStepId: '12000000-0000-0000-0000-000000000001',
          stepIndex: 0,
          instruction: '면을 끓인다.',
          timerSeconds: 120,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
    );

    final preflight = preflightPersonalVersionApproval(legacyPersonalSnapshot);
    expect(preflight, isA<PersonalVersionApprovalRequiresReanchor>());
    expect(
      (preflight as PersonalVersionApprovalRequiresReanchor).message,
      contains('원본 재료'),
    );
    expect(
      () => PersonalVersionApprovalRequest.fromSnapshot(
        snapshot: legacyPersonalSnapshot,
      ),
      throwsA(
        isA<PersonalVersionApprovalApiException>().having(
          (error) => error.message,
          'message',
          contains('원본 재료'),
        ),
      ),
    );
  });

  test('원본 baseline이 완전한 개인 버전 스냅샷은 누적 diff를 만든다', () {
    final anchoredPersonalSnapshot = CookingSetupSnapshot(
      recipeId: recipeId,
      title: '내 라면 v2',
      description: '',
      imageUrl: '',
      baseServings: 1,
      targetServings: 2,
      source: CookingRecipeSource.personal,
      personalVersionId: versionId,
      ingredients: const <CookingSetupIngredient>[
        CookingSetupIngredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          originalName: '물',
          name: '육수',
          amount: 600,
          baselineAmount: 500,
          baselineUnit: 'ml',
          baselineIsRequired: true,
          unit: 'ml',
          isRequired: true,
        ),
      ],
      steps: const <CookingSetupStep>[
        CookingSetupStep(
          originalStepId: '12000000-0000-0000-0000-000000000001',
          stepIndex: 0,
          instruction: '면을 끓인다.',
          timerSeconds: 120,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
    );

    expect(
      preflightPersonalVersionApproval(anchoredPersonalSnapshot),
      isA<PersonalVersionApprovalReady>(),
    );
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: anchoredPersonalSnapshot,
    ).toJson();
    final setup = request['setup'] as Map<String, Object?>;

    expect(setup['ingredientAdjustments'], <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000001',
        'type': 'MODIFY',
        'name': '육수',
        'amount': 600.0,
        'sortOrder': 0,
      },
    ]);
  });

  test('원본 재료의 이름과 양이 모두 바뀌면 MODIFY 한 건에 변경값만 보낸다', () {
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(
        ingredients: const <CookingSetupIngredient>[
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            originalName: '물',
            name: '육수',
            amount: 650,
            baselineAmount: 500,
            unit: 'ml',
            isRequired: true,
          ),
        ],
      ),
    ).toJson();

    final setup = request['setup'] as Map<String, Object?>;
    final adjustments =
        setup['ingredientAdjustments'] as List<Map<String, Object?>>;
    expect(adjustments.single, <String, Object?>{
      'originalIngredientId': '11000000-0000-0000-0000-000000000001',
      'type': 'MODIFY',
      'name': '육수',
      'amount': 650.0,
      'sortOrder': 0,
    });
  });

  test('MODIFY의 amount 삭제와 미변경을 구분하고 ADD REMOVE 형태를 유지한다', () {
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(
        ingredients: const <CookingSetupIngredient>[
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            originalName: '물',
            name: '물',
            amount: null,
            baselineAmount: 500,
            unit: 'ml',
            isRequired: true,
          ),
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000002',
            originalName: '물',
            name: '육수',
            amount: 500,
            baselineAmount: 500,
            baselineUnit: 'ml',
            baselineIsRequired: true,
            unit: '컵',
            isRequired: false,
          ),
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000003',
            originalName: '소금',
            name: '소금',
            amount: 3,
            baselineAmount: 2,
            unit: 'g',
            isRequired: true,
          ),
          CookingSetupIngredient(
            originalName: '치즈',
            name: '치즈',
            amount: 1,
            unit: '장',
            isRequired: false,
          ),
          CookingSetupIngredient(
            originalName: '후추',
            name: '후추',
            amount: null,
            unit: '약간',
            isRequired: false,
          ),
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000004',
            originalName: '계란',
            name: '계란',
            amount: 1,
            baselineAmount: 1,
            unit: '개',
            isRequired: true,
            omitted: true,
          ),
        ],
      ),
    ).toJson();

    final setup = request['setup'] as Map<String, Object?>;
    expect(setup['ingredientAdjustments'], <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000001',
        'type': 'MODIFY',
        'amount': null,
        'sortOrder': 0,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000002',
        'type': 'MODIFY',
        'name': '육수',
        'unit': '컵',
        'required': false,
        'sortOrder': 1,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000003',
        'type': 'MODIFY',
        'amount': 3.0,
        'sortOrder': 2,
      },
      <String, Object?>{
        'type': 'ADD',
        'name': '치즈',
        'amount': 1.0,
        'unit': '장',
        'required': false,
        'sortOrder': 3,
      },
      <String, Object?>{
        'type': 'ADD',
        'name': '후추',
        'amount': null,
        'unit': '약간',
        'required': false,
        'sortOrder': 4,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000004',
        'type': 'REMOVE',
        'sortOrder': 5,
      },
    ]);
  });

  test('API body에 숫자 수량 삭제를 amount null로 명시한다', () async {
    late String rawRequestBody;
    final api = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        rawRequestBody = request.body;
        return http.Response('', 201);
      }),
    );

    await api.createFromApprovedReview(
      reviewId: reviewId,
      snapshot: _snapshotWith(
        ingredients: const <CookingSetupIngredient>[
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            originalName: '물',
            name: '물',
            amount: null,
            baselineAmount: 500,
            unit: 'ml',
            isRequired: true,
          ),
        ],
      ),
    );

    final body = jsonDecode(rawRequestBody) as Map<String, dynamic>;
    final setup = body['setup'] as Map<String, dynamic>;
    final adjustments = setup['ingredientAdjustments'] as List<dynamic>;
    final adjustment = adjustments.single as Map<String, dynamic>;
    expect(adjustment.containsKey('amount'), isTrue);
    expect(adjustment['amount'], isNull);
    expect(rawRequestBody, contains('"amount":null'));
  });

  test('개인 버전 합성 결과도 원본 기준 REMOVE ADD inherited MODIFY를 모두 유지한다', () {
    final ingredients = buildOriginalAnchoredSetupIngredients(
      baseIngredients: const <Ingredient>[
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          name: '물',
          amount: 500,
          unit: 'ml',
          isRequired: true,
        ),
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000002',
          name: '계란',
          amount: 1,
          unit: '개',
          isRequired: false,
        ),
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000003',
          name: '소금',
          amount: 2,
          unit: 'g',
          isRequired: true,
        ),
      ],
      composedIngredients: const <Ingredient>[
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          name: '육수',
          amount: 600,
          unit: '컵',
          isRequired: false,
        ),
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000003',
          name: '소금',
          amount: 2,
          unit: 'g',
          isRequired: true,
        ),
        Ingredient(name: '치즈', amount: 1, unit: '장', isRequired: false),
      ],
      scale: 2,
    );
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(ingredients: ingredients),
    ).toJson();

    final setup = request['setup'] as Map<String, Object?>;
    expect(setup['ingredientAdjustments'], <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000001',
        'type': 'MODIFY',
        'name': '육수',
        'amount': 1200.0,
        'unit': '컵',
        'required': false,
        'sortOrder': 0,
      },
      <String, Object?>{
        'type': 'ADD',
        'name': '치즈',
        'amount': 2.0,
        'unit': '장',
        'required': false,
        'sortOrder': 2,
      },
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000002',
        'type': 'REMOVE',
        'sortOrder': 3,
      },
    ]);
  });

  test('origin 검증을 통과한 개인 버전은 downstream ADD REMOVE를 오염시키지 않는다', () {
    final detail = PersonalRecipeVersionDetail.fromJson(<String, dynamic>{
      'version': <String, dynamic>{
        'id': versionId,
        'versionNumber': 2,
        'title': '덜 짠 라면 v2',
        'summary': '소금 양 변경과 치즈 추가',
        'createdAt': '2026-07-26T01:00:00Z',
      },
      'ingredients': <Object?>[
        <String, dynamic>{
          'originalIngredientId': '11000000-0000-0000-0000-000000000001',
          'name': '물',
          'amount': 500,
          'unit': 'ml',
          'required': true,
          'origin': 'ORIGINAL',
        },
        <String, dynamic>{
          'originalIngredientId': '11000000-0000-0000-0000-000000000002',
          'name': '소금',
          'amount': 2,
          'unit': 'g',
          'required': true,
          'origin': 'MODIFIED',
        },
        <String, dynamic>{
          'originalIngredientId': null,
          'name': '치즈',
          'amount': 1,
          'unit': '장',
          'required': false,
          'origin': 'ADDED',
        },
      ],
      'steps': <Object?>[],
    });
    final ingredients = buildOriginalAnchoredSetupIngredients(
      baseIngredients: const <Ingredient>[
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          name: '물',
          amount: 500,
          unit: 'ml',
          isRequired: true,
        ),
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000002',
          name: '소금',
          amount: 1,
          unit: 'g',
          isRequired: true,
        ),
      ],
      composedIngredients: detail.ingredients,
      scale: 1,
    );

    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(ingredients: ingredients),
    ).toJson();
    final setup = request['setup'] as Map<String, Object?>;

    expect(setup['ingredientAdjustments'], <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000002',
        'type': 'MODIFY',
        'amount': 2.0,
        'sortOrder': 1,
      },
      <String, Object?>{
        'type': 'ADD',
        'name': '치즈',
        'amount': 1.0,
        'unit': '장',
        'required': false,
        'sortOrder': 2,
      },
    ]);
  });

  test('원본 수량이 null이면 개인 버전의 숫자 수량을 누적 MODIFY로 유지한다', () {
    final ingredients = buildOriginalAnchoredSetupIngredients(
      baseIngredients: const <Ingredient>[
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          name: '소금',
          amount: null,
          unit: '약간',
          isRequired: true,
        ),
      ],
      composedIngredients: const <Ingredient>[
        Ingredient(
          originalIngredientId: '11000000-0000-0000-0000-000000000001',
          name: '소금',
          amount: 2,
          unit: '약간',
          isRequired: true,
        ),
      ],
      scale: 1,
    );

    expect(ingredients.single.baselineAmount, isNull);

    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(ingredients: ingredients),
    ).toJson();
    final setup = request['setup'] as Map<String, Object?>;
    expect(setup['ingredientAdjustments'], <Map<String, Object?>>[
      <String, Object?>{
        'originalIngredientId': '11000000-0000-0000-0000-000000000001',
        'type': 'MODIFY',
        'amount': 2.0,
        'sortOrder': 0,
      },
    ]);
  });

  test('개인 버전 합성 결과의 원본 ID가 없거나 중복되면 조용히 diff를 잃지 않는다', () {
    const base = <Ingredient>[
      Ingredient(
        originalIngredientId: '11000000-0000-0000-0000-000000000001',
        name: '물',
        amount: 500,
        unit: 'ml',
        isRequired: true,
      ),
    ];

    expect(
      () => buildOriginalAnchoredSetupIngredients(
        baseIngredients: base,
        composedIngredients: const <Ingredient>[
          Ingredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000099',
            name: '육수',
            amount: 500,
            unit: 'ml',
            isRequired: true,
          ),
        ],
        scale: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildOriginalAnchoredSetupIngredients(
        baseIngredients: base,
        composedIngredients: const <Ingredient>[
          Ingredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            name: '물',
            amount: 500,
            unit: 'ml',
            isRequired: true,
          ),
          Ingredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            name: '육수',
            amount: 600,
            unit: 'ml',
            isRequired: true,
          ),
        ],
        scale: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildOriginalAnchoredSetupIngredients(
        baseIngredients: const <Ingredient>[
          Ingredient(name: '식별자 없는 원본', amount: 1, unit: '개', isRequired: true),
        ],
        composedIngredients: const <Ingredient>[],
        scale: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildOriginalAnchoredSetupIngredients(
        baseIngredients: const <Ingredient>[
          Ingredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            name: '물',
            amount: 500,
            unit: 'ml',
            isRequired: true,
          ),
          Ingredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            name: '중복된 물',
            amount: 600,
            unit: 'ml',
            isRequired: true,
          ),
        ],
        composedIngredients: const <Ingredient>[],
        scale: 1,
      ),
      throwsArgumentError,
    );
  });

  test('취소된 추가 재료와 변경 없는 원본 재료는 diff에서 제외한다', () {
    final request = PersonalVersionApprovalRequest.fromSnapshot(
      snapshot: _snapshotWith(
        ingredients: const <CookingSetupIngredient>[
          CookingSetupIngredient(
            originalIngredientId: '11000000-0000-0000-0000-000000000001',
            originalName: '물',
            name: '물',
            amount: 500.00001,
            baselineAmount: 500,
            unit: 'ml',
            isRequired: true,
          ),
          CookingSetupIngredient(
            originalName: '치즈',
            name: '치즈',
            amount: 1,
            baselineAmount: 1,
            unit: '장',
            isRequired: false,
            omitted: true,
          ),
        ],
      ),
    ).toJson();

    final setup = request['setup'] as Map<String, Object?>;
    expect(setup['ingredientAdjustments'], isEmpty);
  });

  test('204 응답은 오류가 아니라 변경 없음 결과로 반환한다', () async {
    final api = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('', 204)),
    );

    final result = await api.createFromApprovedReview(
      reviewId: reviewId,
      snapshot: _editedSnapshot,
    );

    expect(result, isA<PersonalVersionNoChange>());
  });

  test('201 응답은 body가 비어 있어도 생성 marker로 처리한다', () async {
    final api = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('', 201)),
    );

    final result = await api.createFromApprovedReview(
      reviewId: reviewId,
      snapshot: _editedSnapshot,
    );

    expect(result, isA<PersonalVersionCreated>());
  });

  test('HTTP 오류와 timeout을 typed API 예외로 변환한다', () async {
    final errorApi = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      client: MockClient((_) async => http.Response('not found', 404)),
    );
    await expectLater(
      errorApi.createFromApprovedReview(
        reviewId: reviewId,
        snapshot: _editedSnapshot,
      ),
      throwsA(
        isA<PersonalVersionApprovalApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.message, 'message', contains('후기 기록')),
      ),
    );

    final pending = Completer<http.Response>();
    final timeoutApi = PersonalVersionApprovalApi(
      baseUrl: baseUrl,
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => pending.future),
    );
    await expectLater(
      timeoutApi.createFromApprovedReview(
        reviewId: reviewId,
        snapshot: _editedSnapshot,
      ),
      throwsA(
        isA<PersonalVersionApprovalApiException>().having(
          (error) => error.message,
          'message',
          contains('초과'),
        ),
      ),
    );
  });
}

final CookingSetupSnapshot _editedSnapshot = _snapshotWith(
  ingredients: const <CookingSetupIngredient>[
    CookingSetupIngredient(
      originalIngredientId: '11000000-0000-0000-0000-000000000001',
      originalName: '물',
      name: '물',
      amount: 500,
      baselineAmount: 500,
      unit: 'ml',
      isRequired: true,
    ),
    CookingSetupIngredient(
      originalIngredientId: '11000000-0000-0000-0000-000000000002',
      originalName: '계란',
      name: '계란',
      amount: 1,
      baselineAmount: 1,
      unit: '개',
      isRequired: false,
      omitted: true,
    ),
    CookingSetupIngredient(
      originalIngredientId: '11000000-0000-0000-0000-000000000003',
      originalName: '대파',
      name: '쪽파',
      amount: 10,
      baselineAmount: 10,
      unit: 'g',
      isRequired: false,
    ),
    CookingSetupIngredient(
      originalIngredientId: '11000000-0000-0000-0000-000000000004',
      originalName: '소금',
      name: '소금',
      amount: 2.5,
      baselineAmount: 2,
      unit: 'g',
      isRequired: true,
    ),
    CookingSetupIngredient(
      originalName: '치즈',
      name: '치즈',
      amount: 1,
      baselineAmount: 1,
      unit: '장',
      isRequired: false,
    ),
  ],
);

CookingSetupSnapshot _snapshotWith({
  required List<CookingSetupIngredient> ingredients,
}) {
  return CookingSetupSnapshot(
    recipeId: '10000000-0000-0000-0000-000000000001',
    title: '라면',
    description: '',
    imageUrl: '',
    baseServings: 1,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: ingredients,
    steps: const <CookingSetupStep>[
      CookingSetupStep(
        originalStepId: '12000000-0000-0000-0000-000000000001',
        stepIndex: 0,
        instruction: '면을 끓인다.',
        timerSeconds: 999,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
  );
}

http.Response _jsonResponse(String body, {required int statusCode}) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: const <String, String>{'Content-Type': 'application/json'},
  );
}
