import 'dart:async';
import 'dart:convert';

import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PendingReviewDraft', () {
    test('모든 복구 필드를 JSON으로 왕복하고 사용자 입력 공백을 보존한다', () {
      final draft = buildDraft(
        comment: '  맛있었어요  ',
        nextTimeNote: ' 다음에는 물을 덜 넣기 ',
        approvedPersonalVersionCreation: true,
        acceptedReviewId: acceptedReviewId,
      );

      final restored = PendingReviewDraft.fromJson(draft.toJson());

      expect(restored, isNotNull);
      expect(restored!.clientSessionId, clientSessionId);
      expect(restored.cookedAt, DateTime.utc(2026, 7, 30, 8, 30));
      expect(restored.setupSnapshot.recipeId, recipeId);
      expect(restored.setupSnapshot.ingredients.single.name, '두부');
      expect(restored.setupSnapshot.steps.single.instruction, '두부를 부친다.');
      expect(restored.timerSecondsByStep, const {0: 180});
      expect(restored.rating, 4);
      expect(restored.comment, '  맛있었어요  ');
      expect(restored.nextTimeNote, ' 다음에는 물을 덜 넣기 ');
      expect(restored.approvedPersonalVersionCreation, isTrue);
      expect(restored.acceptedReviewId, acceptedReviewId);
      expect(() => restored.timerSecondsByStep[0] = 10, throwsUnsupportedError);
    });

    test('cookedAt은 직렬화된 canonical UTC 형식만 복원한다', () {
      final canonicalJson = buildDraft().toJson();
      expect(canonicalJson['cookedAt'], '2026-07-30T08:30:00.000Z');
      expect(PendingReviewDraft.fromJson(canonicalJson), isNotNull);
      expect(
        PendingReviewDraft.fromJson(<String, Object?>{
          ...canonicalJson,
          'cookedAt': '2024-02-29T08:30:00.000Z',
        }),
        isNotNull,
      );

      final microsecondJson = buildDraft(
        cookedAt: DateTime.utc(2026, 7, 30, 8, 30, 0, 123, 456),
      ).toJson();
      expect(microsecondJson['cookedAt'], '2026-07-30T08:30:00.123456Z');
      expect(PendingReviewDraft.fromJson(microsecondJson), isNotNull);

      const invalidValues = <String>[
        '2026-01-42T08:30:00.000Z',
        '2026-13-01T08:30:00.000Z',
        '2025-02-29T08:30:00.000Z',
        '2026-07-30T17:30:00.000+09:00',
        '2026-07-30T08:30:00.000',
        '2026-07-30 08:30:00.000Z',
        '2026-07-30T08:30:00Z',
        '2026-07-30T08:30:00.0Z',
        '2026-07-30T08:30:00.123000Z',
      ];

      for (final value in invalidValues) {
        expect(
          PendingReviewDraft.fromJson(<String, Object?>{
            ...canonicalJson,
            'cookedAt': value,
          }),
          isNull,
          reason: '$value 형식은 복원하지 않아야 한다.',
        );
      }
    });

    test('v1 draft를 후기 접수 ID가 없는 현재 스키마로 마이그레이션한다', () {
      final legacyJson =
          buildDraft(approvedPersonalVersionCreation: true).toJson()
            ..['schemaVersion'] = 1
            ..remove('acceptedReviewId');

      final restored = PendingReviewDraft.fromJson(legacyJson);

      expect(restored, isNotNull);
      expect(restored!.acceptedReviewId, isNull);
      expect(
        restored.toJson(),
        containsPair('schemaVersion', PendingReviewDraft.currentSchemaVersion),
      );
      expect(restored.toJson(), containsPair('acceptedReviewId', isNull));
    });

    test('후기 길이는 UTF-16 길이가 아닌 Unicode code point로 검사한다', () {
      final maximumComment = List.filled(
        PendingReviewDraft.maximumCommentCodePoints,
        '🍳',
      ).join();
      final maximumNote = List.filled(
        PendingReviewDraft.maximumNextTimeNoteCodePoints,
        '🍚',
      ).join();

      expect(
        buildDraft(comment: maximumComment, nextTimeNote: maximumNote).comment,
        maximumComment,
      );
      expect(
        () => buildDraft(comment: '$maximumComment🍳'),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(nextTimeNote: '$maximumNote🍚'),
        throwsArgumentError,
      );
    });

    test('필수 별점, canonical UUID, DB 비호환 문자를 거부한다', () {
      expect(() => buildDraft(rating: 0), throwsArgumentError);
      expect(() => buildDraft(rating: 6), throwsArgumentError);
      expect(
        () => buildDraft(clientSessionIdValue: 'not-a-uuid'),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(
          clientSessionIdValue: '00000000-0000-0000-0000-000000000000',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(acceptedReviewId: 'not-a-uuid'),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(
          acceptedReviewId: '00000000-0000-0000-0000-000000000000',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(acceptedReviewId: acceptedReviewId),
        throwsArgumentError,
      );
      expect(() => buildDraft(comment: '앞\u0000뒤'), throwsArgumentError);
      expect(
        () => buildDraft(nextTimeNote: String.fromCharCode(0xd800)),
        throwsArgumentError,
      );
    });

    test('실행 스냅샷과 타이머 단계의 무결성을 검사한다', () {
      expect(
        () => buildDraft(
          setupSnapshot: buildSetupSnapshot(recipeIdValue: 'invalid'),
        ),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(setupSnapshot: buildSetupSnapshot(stepIndex: 1)),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(timerSecondsByStep: const {1: 180}),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(timerSecondsByStep: const {0: -1}),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(setupSnapshot: buildSetupSnapshot(baseServings: 0)),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(setupSnapshot: buildSetupSnapshot(targetServings: 0)),
        throwsArgumentError,
      );
      expect(
        () =>
            buildDraft(setupSnapshot: buildSetupSnapshot(targetServings: 100)),
        throwsArgumentError,
      );
      expect(
        () => buildDraft(
          setupSnapshot: buildSetupSnapshot(includeStep: false),
          timerSecondsByStep: const {},
        ),
        throwsArgumentError,
      );
    });

    test('재료 amount와 baselineAmount는 null 또는 음이 아닌 finite 값만 허용한다', () {
      CookingSetupSnapshot snapshotWith(String field, double? value) {
        return buildSetupSnapshot(
          ingredientAmount: field == 'amount' ? value : 1,
          ingredientBaselineAmount: field == 'baselineAmount' ? value : 1,
        );
      }

      for (final field in const <String>['amount', 'baselineAmount']) {
        for (final value in <double?>[null, 0, 1.5]) {
          final draft = buildDraft(setupSnapshot: snapshotWith(field, value));

          expect(
            PendingReviewDraft.fromJson(draft.toJson()),
            isNotNull,
            reason: '$field의 $value 값은 허용해야 한다.',
          );
        }

        for (final value in <double>[
          -1,
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          expect(
            () => buildDraft(setupSnapshot: snapshotWith(field, value)),
            throwsArgumentError,
            reason: '$field의 $value 값은 모델 생성에서 거부해야 한다.',
          );
          final corrupted = _mutatedDraftJson(
            (setupSnapshot, ingredient, step) => ingredient[field] = value,
          );
          expect(
            PendingReviewDraft.fromJson(corrupted),
            isNull,
            reason: '$field의 $value 값은 저장값 복원에서 거부해야 한다.',
          );
        }
      }
    });

    test('후기 payload에 포함되는 스냅샷 문자열의 NUL을 거부한다', () {
      CookingSetupSnapshot snapshotWithNul(String field) {
        return buildSetupSnapshot(
          ingredientName: field == 'name' ? '두\u0000부' : '두부',
          ingredientUnit: field == 'unit' ? '\u0000모' : '모',
          stepInstruction: field == 'instruction'
              ? '두부를\u0000부친다.'
              : '두부를 부친다.',
          stepCautionNote: field == 'cautionNote'
              ? '기름이\u0000튈 수 있다.'
              : '기름이 튈 수 있다.',
        );
      }

      for (final field in const <String>[
        'name',
        'unit',
        'instruction',
        'cautionNote',
      ]) {
        expect(
          () => buildDraft(setupSnapshot: snapshotWithNul(field)),
          throwsArgumentError,
          reason: '$field의 NUL은 모델 생성에서 거부해야 한다.',
        );
        final corrupted = _mutatedDraftJson((setupSnapshot, ingredient, step) {
          if (field == 'name' || field == 'unit') {
            ingredient[field] = '앞\u0000뒤';
          } else {
            step[field] = '앞\u0000뒤';
          }
        });
        expect(
          PendingReviewDraft.fromJson(corrupted),
          isNull,
          reason: '$field의 NUL은 저장값 복원에서 거부해야 한다.',
        );
      }
    });

    test('재료 baselineUnit의 DB 비호환 문자를 거부한다', () {
      for (final invalidUnit in <String>[
        '앞\u0000뒤',
        String.fromCharCode(0xd800),
        String.fromCharCode(0xdc00),
      ]) {
        expect(
          () => buildDraft(
            setupSnapshot: buildSetupSnapshot(
              ingredientBaselineUnit: invalidUnit,
            ),
          ),
          throwsArgumentError,
          reason: 'baselineUnit의 DB 비호환 문자는 모델 생성에서 거부해야 한다.',
        );
        final corrupted = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) =>
              ingredient['baselineUnit'] = invalidUnit,
        );
        expect(
          PendingReviewDraft.fromJson(corrupted),
          isNull,
          reason: 'baselineUnit의 DB 비호환 문자는 저장값 복원에서 거부해야 한다.',
        );
      }
    });

    test('실행 단계 기본 타이머는 null과 지원 범위 경계만 허용한다', () {
      for (final timerSeconds in <int?>[
        null,
        0,
        PendingReviewDraft.maximumTimerSeconds,
      ]) {
        final draft = buildDraft(
          setupSnapshot: buildSetupSnapshot(stepTimerSeconds: timerSeconds),
          timerSecondsByStep: const {},
        );

        final restored = PendingReviewDraft.fromJson(draft.toJson());

        expect(restored, isNotNull);
        expect(restored!.setupSnapshot.steps.single.timerSeconds, timerSeconds);
      }

      for (final timerSeconds in <int>[
        -1,
        PendingReviewDraft.maximumTimerSeconds + 1,
      ]) {
        expect(
          () => buildDraft(
            setupSnapshot: buildSetupSnapshot(stepTimerSeconds: timerSeconds),
            timerSecondsByStep: const {},
          ),
          throwsArgumentError,
        );
        final corrupted = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) =>
              step['timerSeconds'] = timerSeconds,
        );
        corrupted['timerSecondsByStep'] = <String, Object?>{};
        expect(PendingReviewDraft.fromJson(corrupted), isNull);
      }
    });

    test('현재 스키마의 필드가 빠지거나 추가된 JSON은 읽지 않는다', () {
      final missing = buildDraft().toJson()..remove('rating');
      final unknown = buildDraft().toJson()..['futureField'] = true;
      final invalidAcceptedReviewId = buildDraft().toJson()
        ..['acceptedReviewId'] = 'invalid';

      expect(PendingReviewDraft.fromJson(missing), isNull);
      expect(PendingReviewDraft.fromJson(unknown), isNull);
      expect(PendingReviewDraft.fromJson(invalidAcceptedReviewId), isNull);
    });

    test('현재 후기 실행 스냅샷은 UI 범위 밖 targetServings를 읽지 않는다', () {
      for (final targetServings in const [0, 100]) {
        final json = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) =>
              setupSnapshot['targetServings'] = targetServings,
        );

        expect(
          PendingReviewDraft.fromJson(json),
          isNull,
          reason: '$targetServings인분 저장값은 1~99 UI 범위 밖이다.',
        );
      }

      for (final targetServings in const [1, 99]) {
        final draft = buildDraft(
          setupSnapshot: buildSetupSnapshot(targetServings: targetServings),
        );

        expect(PendingReviewDraft.fromJson(draft.toJson()), isNotNull);
      }
    });

    test('PR35 legacy 재료 shape를 current nullable baseline shape로 보완한다', () {
      final legacyJson = _pr35LegacyDraftJson();

      final restored = PendingReviewDraft.fromJson(legacyJson);

      expect(restored, isNotNull);
      final restoredIngredient = restored!.setupSnapshot.ingredients.single;
      expect(restoredIngredient.baselineUnit, isNull);
      expect(restoredIngredient.baselineIsRequired, isNull);

      final migratedJson = restored.toJson();
      expect(
        migratedJson['schemaVersion'],
        PendingReviewDraft.currentSchemaVersion,
      );
      final migratedIngredient = _firstIngredientJson(migratedJson);
      expect(migratedIngredient, containsPair('baselineUnit', isNull));
      expect(migratedIngredient, containsPair('baselineIsRequired', isNull));
      final originalLegacyIngredient = _firstIngredientJson(legacyJson);
      expect(originalLegacyIngredient.containsKey('baselineUnit'), isFalse);
      expect(
        originalLegacyIngredient.containsKey('baselineIsRequired'),
        isFalse,
      );
    });

    test('legacy 재료의 누락 hybrid unknown 및 current 혼합 shape는 거부한다', () {
      final missing = _mutatedDraftJsonFrom(
        _pr35LegacyDraftJson(),
        (setupSnapshot, ingredient, step) =>
            ingredient.remove('baselineAmount'),
      );
      final hybrid = _mutatedDraftJsonFrom(
        _pr35LegacyDraftJson(),
        (setupSnapshot, ingredient, step) => ingredient['baselineUnit'] = null,
      );
      final unknown = _mutatedDraftJsonFrom(
        _pr35LegacyDraftJson(),
        (setupSnapshot, ingredient, step) => ingredient['futureField'] = true,
      );
      final mixed = _mutatedDraftJsonFrom(_pr35LegacyDraftJson(), (
        setupSnapshot,
        ingredient,
        step,
      ) {
        setupSnapshot['ingredients'] = <Object?>[
          ingredient,
          buildSetupSnapshot().ingredients.single.toJson(),
        ];
      });

      expect(PendingReviewDraft.fromJson(missing), isNull);
      expect(PendingReviewDraft.fromJson(hybrid), isNull);
      expect(PendingReviewDraft.fromJson(unknown), isNull);
      expect(PendingReviewDraft.fromJson(mixed), isNull);
    });

    test('현재 후기 실행 스냅샷은 모든 최상위 필드를 요구한다', () {
      const fields = <String>[
        'schemaVersion',
        'recipeId',
        'title',
        'description',
        'imageUrl',
        'baseServings',
        'targetServings',
        'source',
        'personalVersionId',
        'ingredients',
        'steps',
      ];

      for (final field in fields) {
        final json = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) => setupSnapshot.remove(field),
        );

        expect(
          PendingReviewDraft.fromJson(json),
          isNull,
          reason: 'setupSnapshot.$field 누락을 거부해야 한다.',
        );
      }
    });

    test('현재 후기 실행 스냅샷의 재료는 nullable 필드를 포함해 모두 요구한다', () {
      const fields = <String>[
        'originalIngredientId',
        'originalName',
        'name',
        'amount',
        'baselineAmount',
        'baselineUnit',
        'baselineIsRequired',
        'unit',
        'isRequired',
        'omitted',
      ];

      for (final field in fields) {
        final json = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) => ingredient.remove(field),
        );

        expect(
          PendingReviewDraft.fromJson(json),
          isNull,
          reason: 'setupSnapshot.ingredients.$field 누락을 거부해야 한다.',
        );
      }
    });

    test('현재 후기 실행 스냅샷의 단계는 nullable 필드를 포함해 모두 요구한다', () {
      const fields = <String>[
        'originalStepId',
        'stepIndex',
        'instruction',
        'timerSeconds',
        'cautionNote',
        'imageUrl',
      ];

      for (final field in fields) {
        final json = _mutatedDraftJson(
          (setupSnapshot, ingredient, step) => step.remove(field),
        );

        expect(
          PendingReviewDraft.fromJson(json),
          isNull,
          reason: 'setupSnapshot.steps.$field 누락을 거부해야 한다.',
        );
      }
    });

    test('현재 후기 실행 스냅샷의 알 수 없는 중첩 필드를 거부한다', () {
      final unknownSnapshot = _mutatedDraftJson(
        (setupSnapshot, ingredient, step) =>
            setupSnapshot['futureField'] = true,
      );
      final unknownIngredient = _mutatedDraftJson(
        (setupSnapshot, ingredient, step) => ingredient['futureField'] = true,
      );
      final unknownStep = _mutatedDraftJson(
        (setupSnapshot, ingredient, step) => step['futureField'] = true,
      );

      expect(PendingReviewDraft.fromJson(unknownSnapshot), isNull);
      expect(PendingReviewDraft.fromJson(unknownIngredient), isNull);
      expect(PendingReviewDraft.fromJson(unknownStep), isNull);
    });

    test('현재 후기 실행 스냅샷의 omitted는 null이 아닌 bool이어야 한다', () {
      final json = _mutatedDraftJson(
        (setupSnapshot, ingredient, step) => ingredient['omitted'] = null,
      );

      expect(PendingReviewDraft.fromJson(json), isNull);
    });

    test('현재 후기 실행 스냅샷은 필수 nullable 키의 null 값을 보존한다', () {
      final json = _mutatedDraftJson((setupSnapshot, ingredient, step) {
        setupSnapshot['personalVersionId'] = null;
        ingredient['originalIngredientId'] = null;
        ingredient['baselineAmount'] = null;
        ingredient['baselineUnit'] = null;
        ingredient['baselineIsRequired'] = null;
        ingredient['omitted'] = true;
        step['originalStepId'] = null;
        step['timerSeconds'] = null;
        step['cautionNote'] = null;
      });

      final restored = PendingReviewDraft.fromJson(json);

      expect(restored, isNotNull);
      expect(restored!.setupSnapshot.personalVersionId, isNull);
      final ingredient = restored.setupSnapshot.ingredients.single;
      expect(ingredient.originalIngredientId, isNull);
      expect(ingredient.amount, 1);
      expect(ingredient.baselineAmount, isNull);
      expect(ingredient.baselineUnit, isNull);
      expect(ingredient.baselineIsRequired, isNull);
      expect(ingredient.omitted, isTrue);
      final step = restored.setupSnapshot.steps.single;
      expect(step.originalStepId, isNull);
      expect(step.timerSeconds, isNull);
      expect(step.cautionNote, isNull);

      final nullableAmountJson = _mutatedDraftJson(
        (setupSnapshot, ingredient, step) => ingredient['amount'] = null,
      );
      final nullableAmount = PendingReviewDraft.fromJson(nullableAmountJson);
      expect(nullableAmount, isNotNull);
      expect(nullableAmount!.setupSnapshot.ingredients.single.amount, isNull);
    });
  });

  group('PendingReviewDraftStore', () {
    test('한 건의 후기 초안을 저장하고 복원한다', () async {
      final store = PendingReviewDraftStore();
      await store.save(buildDraft());

      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.clientSessionId, clientSessionId);
      expect(restored.rating, 4);
      expect(restored.comment, '맛있었어요');
      expect(restored.nextTimeNote, '다음에는 덜 짜게');
      expect(restored.timerSecondsByStep, const {0: 180});
      expect(restored.approvedPersonalVersionCreation, isFalse);
    });

    test('PR35 legacy 초안을 같은 저장키에서 삭제하지 않고 복원한다', () async {
      final legacyJson = _pr35LegacyDraftJson();
      SharedPreferences.setMockInitialValues(<String, Object>{
        PendingReviewDraftStore.storageKey: jsonEncode(legacyJson),
      });
      final store = PendingReviewDraftStore();

      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.setupSnapshot.ingredients.single.baselineUnit, isNull);
      expect(
        restored.setupSnapshot.ingredients.single.baselineIsRequired,
        isNull,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(PendingReviewDraftStore.storageKey),
        isNotNull,
      );

      await store.save(restored);
      final migrated = Map<String, Object?>.from(
        jsonDecode(preferences.getString(PendingReviewDraftStore.storageKey)!)
            as Map,
      );
      expect(
        migrated['schemaVersion'],
        PendingReviewDraft.currentSchemaVersion,
      );
      final migratedIngredient = _firstIngredientJson(migrated);
      expect(migratedIngredient, containsPair('baselineUnit', isNull));
      expect(migratedIngredient, containsPair('baselineIsRequired', isNull));
    });

    test('새 저장은 데모의 기존 단일 초안을 교체한다', () async {
      final store = PendingReviewDraftStore();
      await store.save(buildDraft(rating: 2, comment: '이전 초안'));
      await store.save(
        buildDraft(
          rating: 5,
          comment: '최신 초안',
          approvedPersonalVersionCreation: true,
          acceptedReviewId: acceptedReviewId,
        ),
      );

      final restored = await store.load();

      expect(restored!.rating, 5);
      expect(restored.comment, '최신 초안');
      expect(restored.approvedPersonalVersionCreation, isTrue);
      expect(restored.acceptedReviewId, acceptedReviewId);
    });

    test('저장된 v1 draft를 잃지 않고 불러와 다음 저장에서 v2로 올린다', () async {
      final legacyJson =
          buildDraft(approvedPersonalVersionCreation: true).toJson()
            ..['schemaVersion'] = 1
            ..remove('acceptedReviewId');
      SharedPreferences.setMockInitialValues(<String, Object>{
        PendingReviewDraftStore.storageKey: jsonEncode(legacyJson),
      });
      final store = PendingReviewDraftStore();

      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.acceptedReviewId, isNull);

      await store.save(restored);
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(PendingReviewDraftStore.storageKey);
      final migrated = Map<String, Object?>.from(jsonDecode(raw!) as Map);
      expect(
        migrated['schemaVersion'],
        PendingReviewDraft.currentSchemaVersion,
      );
      expect(migrated, containsPair('acceptedReviewId', isNull));
    });

    test('서로 다른 store의 동시 저장도 요청 순서대로 직렬화한다', () async {
      final preferences = await SharedPreferences.getInstance();
      final firstLoaderGate = Completer<void>();
      var loaderCalls = 0;

      Future<SharedPreferences> delayedLoader() async {
        loaderCalls += 1;
        if (loaderCalls == 1) {
          await firstLoaderGate.future;
        }
        return preferences;
      }

      final firstStore = PendingReviewDraftStore(
        preferencesLoader: delayedLoader,
      );
      final secondStore = PendingReviewDraftStore(
        preferencesLoader: delayedLoader,
      );
      final olderSave = firstStore.save(
        buildDraft(rating: 2, comment: '먼저 요청한 초안'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(loaderCalls, 1);

      final newerSave = secondStore.save(
        buildDraft(rating: 5, comment: '나중에 요청한 최신 초안'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(loaderCalls, 1, reason: '두 번째 저장은 첫 번째 저장이 끝나기 전에 시작하면 안 된다.');

      firstLoaderGate.complete();
      await Future.wait([olderSave, newerSave]);

      final raw = preferences.getString(PendingReviewDraftStore.storageKey);
      final decoded = Map<String, Object?>.from(jsonDecode(raw!) as Map);
      final restored = PendingReviewDraft.fromJson(decoded);
      expect(restored!.rating, 5);
      expect(restored.comment, '나중에 요청한 최신 초안');
    });

    test('앞선 저장이 실패해도 직렬화 큐의 다음 저장은 계속 실행한다', () async {
      final preferences = await SharedPreferences.getInstance();
      var loaderCalls = 0;
      Future<SharedPreferences> failOnceLoader() async {
        loaderCalls += 1;
        if (loaderCalls == 1) {
          throw StateError('temporary preferences failure');
        }
        return preferences;
      }

      final store = PendingReviewDraftStore(preferencesLoader: failOnceLoader);

      await expectLater(store.save(buildDraft()), throwsStateError);
      await store.save(buildDraft(rating: 5, comment: '장애 뒤 최신 초안'));

      final raw = preferences.getString(PendingReviewDraftStore.storageKey);
      final decoded = Map<String, Object?>.from(jsonDecode(raw!) as Map);
      final restored = PendingReviewDraft.fromJson(decoded);
      expect(restored!.rating, 5);
      expect(restored.comment, '장애 뒤 최신 초안');
    });

    test('플랫폼 저장 실패 뒤 캐시를 이전 영속 초안으로 복원한다', () async {
      final previousDraft = buildDraft(rating: 2, comment: '이전 영속 초안');
      final platform = _FailingSetSharedPreferencesStore({
        'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
          previousDraft.toJson(),
        ),
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        store.save(buildDraft(rating: 5, comment: '저장되지 않은 최신 초안')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '후기 초안을 로컬에 저장하지 못했습니다.',
          ),
        ),
      );

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 2);
      expect(restored.comment, '이전 영속 초안');
      expect(platform.setKeys, const [
        'flutter.${PendingReviewDraftStore.storageKey}',
      ]);
      expect(platform.getAllCalls, 2, reason: '초기 load 뒤 캐시 복구는 한 번만 수행한다.');
    });

    test('플랫폼 저장 실패 뒤 영속 초안이 없으면 캐시도 비운다', () async {
      final platform = _FailingSetSharedPreferencesStore(const {});
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(store.save(buildDraft()), throwsStateError);

      expect(await store.load(), isNull);
      expect(
        preferences.containsKey(PendingReviewDraftStore.storageKey),
        isFalse,
      );
      expect(platform.getAllCalls, 2, reason: '초기 load 뒤 캐시 복구는 한 번만 수행한다.');
    });

    test('저장 실패 뒤 reload가 성공하면 작업 전 cache보다 disk 상태를 신뢰한다', () async {
      final cachedDraft = buildDraft(rating: 2, comment: '작업 전 cache 초안');
      final diskDraft = buildDraft(rating: 3, comment: '외부에서 바뀐 disk 초안');
      const platformKey = 'flutter.${PendingReviewDraftStore.storageKey}';
      final platform = _FailingSetSharedPreferencesStore({
        platformKey: jsonEncode(cachedDraft.toJson()),
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      platform.replacePersistedValue(
        platformKey,
        jsonEncode(diskDraft.toJson()),
      );
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(store.save(buildDraft(rating: 5)), throwsStateError);

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 3);
      expect(restored.comment, '외부에서 바뀐 disk 초안');
      expect(platform.getAllCalls, 2);
    });

    test('플랫폼 저장 예외 뒤 이전 영속 초안을 복원하고 원래 stack을 전달한다', () async {
      final previousDraft = buildDraft(rating: 2, comment: '예외 전 영속 초안');
      final writeError = StateError('platform write failed');
      final writeStackTrace = StackTrace.fromString(
        'platform setValue failure stack',
      );
      final platform = _FailingSetSharedPreferencesStore(
        {
          'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
            previousDraft.toJson(),
          ),
        },
        writeError: writeError,
        writeStackTrace: writeStackTrace,
      );
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );
      Object? caughtError;
      StackTrace? caughtStackTrace;

      try {
        await store.save(buildDraft(rating: 5, comment: '예외로 저장되지 않은 최신 초안'));
      } on Object catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
      }

      expect(caughtError, same(writeError));
      expect(caughtStackTrace.toString(), writeStackTrace.toString());
      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 2);
      expect(restored.comment, '예외 전 영속 초안');
      expect(platform.getAllCalls, 2, reason: '초기 load 뒤 캐시 복구는 한 번만 수행한다.');
    });

    test('플랫폼 저장 예외 뒤 영속 초안이 없으면 캐시도 비운다', () async {
      final writeError = StateError('platform write failed');
      final platform = _FailingSetSharedPreferencesStore(
        const {},
        writeError: writeError,
        writeStackTrace: StackTrace.fromString('platform failure stack'),
      );
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(store.save(buildDraft()), throwsA(same(writeError)));

      expect(await store.load(), isNull);
      expect(
        preferences.containsKey(PendingReviewDraftStore.storageKey),
        isFalse,
      );
      expect(platform.getAllCalls, 2, reason: '초기 load 뒤 캐시 복구는 한 번만 수행한다.');
    });

    for (final hasPreviousDraft in [true, false]) {
      for (final writeThrows in [false, true]) {
        final previousState = hasPreviousDraft ? '이전 초안이 있으면' : '이전 초안이 없으면';
        final failureMode = writeThrows ? '저장 예외' : '저장 false';

        test(
          '$failureMode 뒤 reload도 실패해도 $previousState cache와 최초 오류를 보존한다',
          () async {
            final previousDraft = buildDraft(
              rating: 2,
              comment: 'reload 실패 전 초안',
            );
            final persistedValues = <String, Object>{
              if (hasPreviousDraft)
                'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
                  previousDraft.toJson(),
                ),
            };
            final writeError = StateError('initial platform write failed');
            final writeStackTrace = StackTrace.fromString(
              'initial platform write failure stack',
            );
            final reloadError = StateError('reload failed');
            final reloadStackTrace = StackTrace.fromString(
              'reload failure stack',
            );
            final restoreError = StateError('cache restore failed');
            final restoreStackTrace = StackTrace.fromString(
              'cache restore failure stack',
            );
            final platform = _FailingSetSharedPreferencesStore(
              persistedValues,
              writeError: writeThrows ? writeError : null,
              writeStackTrace: writeThrows ? writeStackTrace : null,
              reloadError: reloadError,
              reloadStackTrace: reloadStackTrace,
              restoreError: restoreError,
              restoreStackTrace: restoreStackTrace,
            );
            final originalPlatform = SharedPreferencesStorePlatform.instance;
            addTearDown(() {
              SharedPreferencesStorePlatform.instance = originalPlatform;
            });
            SharedPreferencesStorePlatform.instance = platform;
            final preferences = await SharedPreferences.getInstance();
            final store = PendingReviewDraftStore(
              preferencesLoader: () async => preferences,
            );
            Object? caughtError;
            StackTrace? caughtStackTrace;

            try {
              await store.save(buildDraft(rating: 5, comment: '저장되지 않은 최신 초안'));
            } on Object catch (error, stackTrace) {
              caughtError = error;
              caughtStackTrace = stackTrace;
            }

            if (writeThrows) {
              expect(caughtError, same(writeError));
              expect(caughtStackTrace.toString(), writeStackTrace.toString());
            } else {
              expect(
                caughtError,
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  '후기 초안을 로컬에 저장하지 못했습니다.',
                ),
              );
              expect(caughtError, isNot(same(reloadError)));
              expect(caughtError, isNot(same(restoreError)));
              expect(
                caughtStackTrace.toString(),
                contains('pending_review_draft_store.dart'),
              );
            }

            final restored = await store.load();
            if (hasPreviousDraft) {
              expect(restored, isNotNull);
              expect(restored!.rating, 2);
              expect(restored.comment, 'reload 실패 전 초안');
            } else {
              expect(restored, isNull);
              expect(
                preferences.containsKey(PendingReviewDraftStore.storageKey),
                isFalse,
              );
            }
            expect(platform.getAllCalls, 2);
          },
        );
      }
    }

    test('저장소를 열지 못한 오류를 초안 없음으로 숨기지 않는다', () async {
      final store = PendingReviewDraftStore(
        preferencesLoader: () async {
          throw StateError('preferences unavailable');
        },
      );

      await expectLater(store.load(), throwsStateError);
    });

    test('손상된 JSON과 잘못된 저장 타입은 null로 읽고 즉시 정리한다', () async {
      final store = PendingReviewDraftStore();

      for (final raw in <Object>['{broken json', 42]) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PendingReviewDraftStore.storageKey: raw,
        });

        expect(await store.load(), isNull);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.get(PendingReviewDraftStore.storageKey), isNull);
      }
    });

    test('스키마, UUID, 별점, 후기 길이가 손상되면 값을 정리한다', () async {
      final store = PendingReviewDraftStore();
      final validJson = buildDraft().toJson();
      final corruptedValues = <Map<String, Object?>>[
        <String, Object?>{...validJson, 'schemaVersion': 3},
        <String, Object?>{...validJson, 'clientSessionId': 'invalid'},
        <String, Object?>{...validJson, 'rating': 6},
        <String, Object?>{
          ...validJson,
          'comment': List.filled(
            PendingReviewDraft.maximumCommentCodePoints + 1,
            '가',
          ).join(),
        },
      ];

      for (final corrupted in corruptedValues) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PendingReviewDraftStore.storageKey: jsonEncode(corrupted),
        });

        expect(await store.load(), isNull);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(PendingReviewDraftStore.storageKey),
          isNull,
        );
      }
    });

    test('중첩 실행 스냅샷이나 타이머 맵이 손상되면 값을 정리한다', () async {
      final store = PendingReviewDraftStore();
      final snapshotCorrupted = _deepCopy(buildDraft().toJson());
      final snapshot = Map<String, Object?>.from(
        snapshotCorrupted['setupSnapshot']! as Map,
      );
      snapshot['recipeId'] = 'invalid';
      snapshotCorrupted['setupSnapshot'] = snapshot;

      final timerCorrupted = _deepCopy(buildDraft().toJson());
      timerCorrupted['timerSecondsByStep'] = <String, Object?>{'9': 180};

      for (final corrupted in [snapshotCorrupted, timerCorrupted]) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          PendingReviewDraftStore.storageKey: jsonEncode(corrupted),
        });

        expect(await store.load(), isNull);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(PendingReviewDraftStore.storageKey),
          isNull,
        );
      }
    });

    test('손상값 remove가 false면 캐시를 복원하고 다음 load가 다시 정리한다', () async {
      const corruptedValue = '{broken json';
      final platform = _FailingRemoveSharedPreferencesStore(const {
        'flutter.${PendingReviewDraftStore.storageKey}': corruptedValue,
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      expect(await store.load(), isNull);
      expect(
        preferences.getString(PendingReviewDraftStore.storageKey),
        corruptedValue,
        reason: '실패한 remove가 먼저 지운 메모리 캐시를 디스크 값으로 복원한다.',
      );

      expect(await store.load(), isNull);
      expect(
        preferences.getString(PendingReviewDraftStore.storageKey),
        corruptedValue,
      );
      expect(platform.removedKeys, const [
        'flutter.${PendingReviewDraftStore.storageKey}',
        'flutter.${PendingReviewDraftStore.storageKey}',
      ]);
      expect(
        platform.getAllCalls,
        3,
        reason: '초기 load와 두 번의 실패한 정리 뒤 각각 디스크를 다시 읽는다.',
      );
    });

    test('손상값 remove가 예외여도 캐시를 복원하고 다음 load가 다시 정리한다', () async {
      const corruptedValue = '{still broken json';
      final platform = _FailingRemoveSharedPreferencesStore(const {
        'flutter.${PendingReviewDraftStore.storageKey}': corruptedValue,
      }, removeError: StateError('platform remove failed'));
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      expect(await store.load(), isNull);
      expect(
        preferences.getString(PendingReviewDraftStore.storageKey),
        corruptedValue,
        reason: 'remove 예외를 숨기기 전에 메모리 캐시를 디스크 값으로 복원한다.',
      );

      expect(await store.load(), isNull);
      expect(
        preferences.getString(PendingReviewDraftStore.storageKey),
        corruptedValue,
      );
      expect(platform.removedKeys, const [
        'flutter.${PendingReviewDraftStore.storageKey}',
        'flutter.${PendingReviewDraftStore.storageKey}',
      ]);
      expect(
        platform.getAllCalls,
        3,
        reason: '초기 load와 두 번의 remove 예외 뒤 각각 디스크를 다시 읽는다.',
      );
    });

    for (final removeThrows in [false, true]) {
      final failureMode = removeThrows ? 'remove 예외' : 'remove false';

      test(
        '손상값 $failureMode 뒤 reload와 fallback이 실패해도 다음 load가 정리를 재시도한다',
        () async {
          const corruptedValue = '{reload also fails';
          final removeError = StateError('initial cleanup remove failed');
          final platform = _FailingRemoveSharedPreferencesStore(
            const {
              'flutter.${PendingReviewDraftStore.storageKey}': corruptedValue,
            },
            removeError: removeThrows ? removeError : null,
            removeStackTrace: removeThrows
                ? StackTrace.fromString('initial cleanup remove stack')
                : null,
            reloadError: StateError('cleanup reload failed'),
            reloadStackTrace: StackTrace.fromString('cleanup reload stack'),
            restoreError: StateError('cleanup cache restore failed'),
            restoreStackTrace: StackTrace.fromString(
              'cleanup cache restore stack',
            ),
          );
          final originalPlatform = SharedPreferencesStorePlatform.instance;
          addTearDown(() {
            SharedPreferencesStorePlatform.instance = originalPlatform;
          });
          SharedPreferencesStorePlatform.instance = platform;
          final preferences = await SharedPreferences.getInstance();
          final store = PendingReviewDraftStore(
            preferencesLoader: () async => preferences,
          );

          expect(await store.load(), isNull);
          expect(
            preferences.getString(PendingReviewDraftStore.storageKey),
            corruptedValue,
          );

          expect(await store.load(), isNull);
          expect(
            preferences.getString(PendingReviewDraftStore.storageKey),
            corruptedValue,
          );
          expect(platform.removedKeys, const [
            'flutter.${PendingReviewDraftStore.storageKey}',
            'flutter.${PendingReviewDraftStore.storageKey}',
          ]);
          expect(platform.getAllCalls, 3);
        },
      );
    }

    for (final entry in <String, Object>{
      'bool': true,
      'int': 42,
      'double': 1.5,
      'string list': <String>['broken'],
    }.entries) {
      test(
        'reload 실패 시 손상된 ${entry.key} raw cache를 복원해 cleanup을 재시도한다',
        () async {
          final platform = _FailingRemoveSharedPreferencesStore(
            {'flutter.${PendingReviewDraftStore.storageKey}': entry.value},
            reloadError: StateError('cleanup reload failed'),
            restoreError: StateError('cleanup cache restore failed'),
          );
          final originalPlatform = SharedPreferencesStorePlatform.instance;
          addTearDown(() {
            SharedPreferencesStorePlatform.instance = originalPlatform;
          });
          SharedPreferencesStorePlatform.instance = platform;
          final preferences = await SharedPreferences.getInstance();
          final store = PendingReviewDraftStore(
            preferencesLoader: () async => preferences,
          );

          expect(await store.load(), isNull);
          expect(
            preferences.get(PendingReviewDraftStore.storageKey),
            equals(entry.value),
          );

          expect(await store.load(), isNull);
          expect(
            preferences.get(PendingReviewDraftStore.storageKey),
            equals(entry.value),
          );
          expect(platform.removedKeys, hasLength(2));
          expect(platform.getAllCalls, 3);
        },
      );
    }

    test('clear 후에는 복원할 초안이 없다', () async {
      final store = PendingReviewDraftStore();
      await store.save(buildDraft());

      await store.clear();

      expect(await store.load(), isNull);
    });

    test('플랫폼 remove가 false면 실제 초안을 캐시에 복원하고 실패를 전달한다', () async {
      final persistedDraft = buildDraft(rating: 2, comment: '삭제되지 않은 초안');
      final platform = _FailingRemoveSharedPreferencesStore({
        'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
          persistedDraft.toJson(),
        ),
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        store.clear(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '후기 초안을 로컬에서 정리하지 못했습니다.',
          ),
        ),
      );

      expect(platform.removedKeys, const [
        'flutter.${PendingReviewDraftStore.storageKey}',
      ]);
      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 2);
      expect(restored.comment, '삭제되지 않은 초안');
      expect(
        platform.getAllCalls,
        2,
        reason: '초기 load 뒤 clear 실패의 캐시 복구는 한 번만 수행한다.',
      );
    });

    test('플랫폼 remove 예외 뒤 실제 초안과 원래 stack을 복원한다', () async {
      final persistedDraft = buildDraft(rating: 3, comment: '예외 뒤 남은 초안');
      final removeError = StateError('platform remove failed');
      final removeStackTrace = StackTrace.fromString(
        'platform remove failure stack',
      );
      final platform = _FailingRemoveSharedPreferencesStore(
        {
          'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
            persistedDraft.toJson(),
          ),
        },
        removeError: removeError,
        removeStackTrace: removeStackTrace,
      );
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final store = PendingReviewDraftStore(
        preferencesLoader: () async => preferences,
      );
      Object? caughtError;
      StackTrace? caughtStackTrace;

      try {
        await store.clear();
      } on Object catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
      }

      expect(caughtError, same(removeError));
      expect(caughtStackTrace.toString(), removeStackTrace.toString());
      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 3);
      expect(restored.comment, '예외 뒤 남은 초안');
      expect(platform.removedKeys, const [
        'flutter.${PendingReviewDraftStore.storageKey}',
      ]);
      expect(
        platform.getAllCalls,
        2,
        reason: '초기 load 뒤 clear 실패의 캐시 복구는 한 번만 수행한다.',
      );
    });

    for (final hasPreviousDraft in [true, false]) {
      for (final removeThrows in [false, true]) {
        final previousState = hasPreviousDraft ? '이전 초안이 있으면' : '이전 초안이 없으면';
        final failureMode = removeThrows ? 'remove 예외' : 'remove false';

        test(
          'clear $failureMode 뒤 reload도 실패해도 $previousState cache와 최초 오류를 보존한다',
          () async {
            final previousDraft = buildDraft(
              rating: 3,
              comment: 'reload 실패 뒤 남은 초안',
            );
            final persistedValues = <String, Object>{
              if (hasPreviousDraft)
                'flutter.${PendingReviewDraftStore.storageKey}': jsonEncode(
                  previousDraft.toJson(),
                ),
            };
            final removeError = StateError('initial platform remove failed');
            final removeStackTrace = StackTrace.fromString(
              'initial platform remove failure stack',
            );
            final reloadError = StateError('reload failed');
            final reloadStackTrace = StackTrace.fromString(
              'reload failure stack',
            );
            final restoreError = StateError('cache restore failed');
            final restoreStackTrace = StackTrace.fromString(
              'cache restore failure stack',
            );
            final platform = _FailingRemoveSharedPreferencesStore(
              persistedValues,
              removeError: removeThrows ? removeError : null,
              removeStackTrace: removeThrows ? removeStackTrace : null,
              reloadError: reloadError,
              reloadStackTrace: reloadStackTrace,
              restoreError: restoreError,
              restoreStackTrace: restoreStackTrace,
            );
            final originalPlatform = SharedPreferencesStorePlatform.instance;
            addTearDown(() {
              SharedPreferencesStorePlatform.instance = originalPlatform;
            });
            SharedPreferencesStorePlatform.instance = platform;
            final preferences = await SharedPreferences.getInstance();
            final store = PendingReviewDraftStore(
              preferencesLoader: () async => preferences,
            );
            Object? caughtError;
            StackTrace? caughtStackTrace;

            try {
              await store.clear();
            } on Object catch (error, stackTrace) {
              caughtError = error;
              caughtStackTrace = stackTrace;
            }

            if (removeThrows) {
              expect(caughtError, same(removeError));
              expect(caughtStackTrace.toString(), removeStackTrace.toString());
            } else {
              expect(
                caughtError,
                isA<StateError>().having(
                  (error) => error.message,
                  'message',
                  '후기 초안을 로컬에서 정리하지 못했습니다.',
                ),
              );
              expect(caughtError, isNot(same(reloadError)));
              expect(caughtError, isNot(same(restoreError)));
              expect(
                caughtStackTrace.toString(),
                contains('pending_review_draft_store.dart'),
              );
            }

            final restored = await store.load();
            if (hasPreviousDraft) {
              expect(restored, isNotNull);
              expect(restored!.rating, 3);
              expect(restored.comment, 'reload 실패 뒤 남은 초안');
            } else {
              expect(restored, isNull);
              expect(
                preferences.containsKey(PendingReviewDraftStore.storageKey),
                isFalse,
              );
            }
            expect(platform.getAllCalls, 2);
          },
        );
      }
    }
  });
}

final class _FailingRemoveSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  _FailingRemoveSharedPreferencesStore(
    Map<String, Object> persistedValues, {
    this.removeError,
    this.removeStackTrace,
    this.reloadError,
    this.reloadStackTrace,
    this.restoreError,
    this.restoreStackTrace,
  }) : _persistedValues = Map<String, Object>.from(persistedValues);

  final Map<String, Object> _persistedValues;
  final Object? removeError;
  final StackTrace? removeStackTrace;
  final Object? reloadError;
  final StackTrace? reloadStackTrace;
  final Object? restoreError;
  final StackTrace? restoreStackTrace;
  final List<String> removedKeys = [];
  final List<String> setKeys = [];
  var getAllCalls = 0;

  @override
  Future<bool> clear() async {
    _persistedValues.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    getAllCalls += 1;
    final error = reloadError;
    if (getAllCalls > 1 && error != null) {
      Error.throwWithStackTrace(error, reloadStackTrace ?? StackTrace.current);
    }
    return Map<String, Object>.from(_persistedValues);
  }

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    final cacheRestoreError = restoreError;
    if (removedKeys.length > 1 && cacheRestoreError != null) {
      Error.throwWithStackTrace(
        cacheRestoreError,
        restoreStackTrace ?? StackTrace.current,
      );
    }
    final error = removeError;
    if (error != null) {
      Error.throwWithStackTrace(error, removeStackTrace ?? StackTrace.current);
    }
    return false;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setKeys.add(key);
    final error = restoreError;
    if (error != null) {
      Error.throwWithStackTrace(error, restoreStackTrace ?? StackTrace.current);
    }
    return true;
  }
}

final class _FailingSetSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  _FailingSetSharedPreferencesStore(
    Map<String, Object> persistedValues, {
    this.writeError,
    this.writeStackTrace,
    this.reloadError,
    this.reloadStackTrace,
    this.restoreError,
    this.restoreStackTrace,
  }) : _persistedValues = Map<String, Object>.from(persistedValues);

  final Map<String, Object> _persistedValues;
  final Object? writeError;
  final StackTrace? writeStackTrace;
  final Object? reloadError;
  final StackTrace? reloadStackTrace;
  final Object? restoreError;
  final StackTrace? restoreStackTrace;
  final List<String> setKeys = [];
  final List<String> removedKeys = [];
  var getAllCalls = 0;

  void replacePersistedValue(String key, Object value) {
    _persistedValues[key] = value;
  }

  @override
  Future<bool> clear() async {
    _persistedValues.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    getAllCalls += 1;
    final error = reloadError;
    if (getAllCalls > 1 && error != null) {
      Error.throwWithStackTrace(error, reloadStackTrace ?? StackTrace.current);
    }
    return Map<String, Object>.from(_persistedValues);
  }

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    final error = restoreError;
    if (error != null) {
      Error.throwWithStackTrace(error, restoreStackTrace ?? StackTrace.current);
    }
    _persistedValues.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setKeys.add(key);
    final cacheRestoreError = restoreError;
    if (setKeys.length > 1 && cacheRestoreError != null) {
      Error.throwWithStackTrace(
        cacheRestoreError,
        restoreStackTrace ?? StackTrace.current,
      );
    }
    final error = writeError;
    if (error != null) {
      Error.throwWithStackTrace(error, writeStackTrace ?? StackTrace.current);
    }
    return false;
  }
}

const clientSessionId = '40000000-0000-0000-0000-000000000001';
const recipeId = '10000000-0000-0000-0000-000000000001';
const acceptedReviewId = '50000000-0000-0000-0000-000000000001';

PendingReviewDraft buildDraft({
  String clientSessionIdValue = clientSessionId,
  DateTime? cookedAt,
  CookingSetupSnapshot? setupSnapshot,
  Map<int, int> timerSecondsByStep = const {0: 180},
  int rating = 4,
  String comment = '맛있었어요',
  String nextTimeNote = '다음에는 덜 짜게',
  bool approvedPersonalVersionCreation = false,
  String? acceptedReviewId,
}) {
  return PendingReviewDraft(
    clientSessionId: clientSessionIdValue,
    cookedAt: cookedAt ?? DateTime.utc(2026, 7, 30, 8, 30),
    setupSnapshot: setupSnapshot ?? buildSetupSnapshot(),
    timerSecondsByStep: timerSecondsByStep,
    rating: rating,
    comment: comment,
    nextTimeNote: nextTimeNote,
    approvedPersonalVersionCreation: approvedPersonalVersionCreation,
    acceptedReviewId: acceptedReviewId,
  );
}

CookingSetupSnapshot buildSetupSnapshot({
  String recipeIdValue = recipeId,
  int stepIndex = 0,
  int? stepTimerSeconds = 120,
  double baseServings = 2,
  double? ingredientAmount = 1,
  double? ingredientBaselineAmount = 1,
  String? ingredientBaselineUnit,
  String ingredientName = '두부',
  String ingredientUnit = '모',
  String stepInstruction = '두부를 부친다.',
  String stepCautionNote = '기름이 튈 수 있다.',
  int targetServings = 2,
  bool includeStep = true,
}) {
  return CookingSetupSnapshot(
    recipeId: recipeIdValue,
    title: '두부 조림',
    description: '짭조름한 두부 반찬',
    imageUrl: '',
    baseServings: baseServings,
    targetServings: targetServings,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: [
      CookingSetupIngredient(
        originalIngredientId: '11000000-0000-0000-0000-000000000001',
        originalName: '두부',
        name: ingredientName,
        amount: ingredientAmount,
        baselineAmount: ingredientBaselineAmount,
        baselineUnit: ingredientBaselineUnit,
        unit: ingredientUnit,
        isRequired: true,
      ),
    ],
    steps: includeStep
        ? [
            CookingSetupStep(
              originalStepId: '12000000-0000-0000-0000-000000000001',
              stepIndex: stepIndex,
              instruction: stepInstruction,
              timerSeconds: stepTimerSeconds,
              cautionNote: stepCautionNote,
              imageUrl: '',
            ),
          ]
        : const [],
  );
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, Object?> _pr35LegacyDraftJson() {
  final json = _mutatedDraftJson((setupSnapshot, ingredient, step) {
    ingredient.remove('baselineUnit');
    ingredient.remove('baselineIsRequired');
  });
  json['schemaVersion'] = 1;
  json.remove('acceptedReviewId');
  return json;
}

Map<String, Object?> _firstIngredientJson(Map<String, Object?> draftJson) {
  final setupSnapshot = draftJson['setupSnapshot']! as Map;
  final ingredients = setupSnapshot['ingredients']! as List;
  return Map<String, Object?>.from(ingredients.first! as Map);
}

Map<String, Object?> _mutatedDraftJson(
  void Function(
    Map<String, Object?> setupSnapshot,
    Map<String, Object?> ingredient,
    Map<String, Object?> step,
  )
  mutate,
) => _mutatedDraftJsonFrom(buildDraft().toJson(), mutate);

Map<String, Object?> _mutatedDraftJsonFrom(
  Map<String, Object?> source,
  void Function(
    Map<String, Object?> setupSnapshot,
    Map<String, Object?> ingredient,
    Map<String, Object?> step,
  )
  mutate,
) {
  final json = _deepCopy(source);
  final setupSnapshot = Map<String, Object?>.from(
    json['setupSnapshot']! as Map,
  );
  final ingredients = List<Object?>.from(setupSnapshot['ingredients']! as List);
  final ingredient = Map<String, Object?>.from(ingredients.single! as Map);
  ingredients[0] = ingredient;
  setupSnapshot['ingredients'] = ingredients;
  final steps = List<Object?>.from(setupSnapshot['steps']! as List);
  final step = Map<String, Object?>.from(steps.single! as Map);
  steps[0] = step;
  setupSnapshot['steps'] = steps;
  mutate(setupSnapshot, ingredient, step);
  json['setupSnapshot'] = setupSnapshot;
  return json;
}
