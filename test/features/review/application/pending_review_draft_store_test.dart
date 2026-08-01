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
      expect(() => restored.timerSecondsByStep[0] = 10, throwsUnsupportedError);
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
        () => buildDraft(
          setupSnapshot: buildSetupSnapshot(includeStep: false),
          timerSecondsByStep: const {},
        ),
        throwsArgumentError,
      );
    });

    test('현재 스키마의 필드가 빠지거나 추가된 JSON은 읽지 않는다', () {
      final missing = buildDraft().toJson()..remove('rating');
      final unknown = buildDraft().toJson()..['futureField'] = true;

      expect(PendingReviewDraft.fromJson(missing), isNull);
      expect(PendingReviewDraft.fromJson(unknown), isNull);
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

    test('새 저장은 데모의 기존 단일 초안을 교체한다', () async {
      final store = PendingReviewDraftStore();
      await store.save(buildDraft(rating: 2, comment: '이전 초안'));
      await store.save(
        buildDraft(
          rating: 5,
          comment: '최신 초안',
          approvedPersonalVersionCreation: true,
        ),
      );

      final restored = await store.load();

      expect(restored!.rating, 5);
      expect(restored.comment, '최신 초안');
      expect(restored.approvedPersonalVersionCreation, isTrue);
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
        <String, Object?>{...validJson, 'schemaVersion': 2},
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
  });
}

final class _FailingRemoveSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  _FailingRemoveSharedPreferencesStore(
    Map<String, Object> persistedValues, {
    this.removeError,
    this.removeStackTrace,
  }) : _persistedValues = Map<String, Object>.from(persistedValues);

  final Map<String, Object> _persistedValues;
  final Object? removeError;
  final StackTrace? removeStackTrace;
  final List<String> removedKeys = [];
  var getAllCalls = 0;

  @override
  Future<bool> clear() async {
    _persistedValues.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    getAllCalls += 1;
    return Map<String, Object>.from(_persistedValues);
  }

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    final error = removeError;
    if (error != null) {
      Error.throwWithStackTrace(error, removeStackTrace ?? StackTrace.current);
    }
    return false;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      true;
}

final class _FailingSetSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  _FailingSetSharedPreferencesStore(
    Map<String, Object> persistedValues, {
    this.writeError,
    this.writeStackTrace,
  }) : _persistedValues = Map<String, Object>.from(persistedValues);

  final Map<String, Object> _persistedValues;
  final Object? writeError;
  final StackTrace? writeStackTrace;
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
    return Map<String, Object>.from(_persistedValues);
  }

  @override
  Future<bool> remove(String key) async {
    _persistedValues.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setKeys.add(key);
    final error = writeError;
    if (error != null) {
      Error.throwWithStackTrace(error, writeStackTrace ?? StackTrace.current);
    }
    return false;
  }
}

const clientSessionId = '40000000-0000-0000-0000-000000000001';
const recipeId = '10000000-0000-0000-0000-000000000001';

PendingReviewDraft buildDraft({
  String clientSessionIdValue = clientSessionId,
  CookingSetupSnapshot? setupSnapshot,
  Map<int, int> timerSecondsByStep = const {0: 180},
  int rating = 4,
  String comment = '맛있었어요',
  String nextTimeNote = '다음에는 덜 짜게',
  bool approvedPersonalVersionCreation = false,
}) {
  return PendingReviewDraft(
    clientSessionId: clientSessionIdValue,
    cookedAt: DateTime.utc(2026, 7, 30, 8, 30),
    setupSnapshot: setupSnapshot ?? buildSetupSnapshot(),
    timerSecondsByStep: timerSecondsByStep,
    rating: rating,
    comment: comment,
    nextTimeNote: nextTimeNote,
    approvedPersonalVersionCreation: approvedPersonalVersionCreation,
  );
}

CookingSetupSnapshot buildSetupSnapshot({
  String recipeIdValue = recipeId,
  int stepIndex = 0,
  double baseServings = 2,
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
    ingredients: const [
      CookingSetupIngredient(
        originalIngredientId: '11000000-0000-0000-0000-000000000001',
        originalName: '두부',
        name: '두부',
        amount: 1,
        baselineAmount: 1,
        unit: '모',
        isRequired: true,
      ),
    ],
    steps: includeStep
        ? [
            CookingSetupStep(
              originalStepId: '12000000-0000-0000-0000-000000000001',
              stepIndex: stepIndex,
              instruction: '두부를 부친다.',
              timerSeconds: 120,
              cautionNote: '기름이 튈 수 있다.',
              imageUrl: '',
            ),
          ]
        : const [],
  );
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, Object?> _mutatedDraftJson(
  void Function(
    Map<String, Object?> setupSnapshot,
    Map<String, Object?> ingredient,
    Map<String, Object?> step,
  )
  mutate,
) {
  final json = _deepCopy(buildDraft().toJson());
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
