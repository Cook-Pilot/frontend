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
      final platform = _FalseSetSharedPreferencesStore({
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
    });

    test('플랫폼 저장 실패 뒤 영속 초안이 없으면 캐시도 비운다', () async {
      final platform = _FalseSetSharedPreferencesStore(const {});
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

    test('clear 후에는 복원할 초안이 없다', () async {
      final store = PendingReviewDraftStore();
      await store.save(buildDraft());

      await store.clear();

      expect(await store.load(), isNull);
    });

    test('플랫폼 remove가 false면 캐시에서 키가 사라져도 실패를 전달한다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PendingReviewDraftStore.storageKey: 'draft',
      });
      final preferences = await SharedPreferences.getInstance();
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      final platform = _FalseRemoveSharedPreferencesStore();
      SharedPreferencesStorePlatform.instance = platform;
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
      expect(
        preferences.containsKey(PendingReviewDraftStore.storageKey),
        isFalse,
        reason: 'SharedPreferences는 플랫폼 결과와 무관하게 먼저 메모리 캐시를 지운다.',
      );
    });
  });
}

final class _FalseRemoveSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  final List<String> removedKeys = [];

  @override
  Future<bool> clear() async => true;

  @override
  Future<Map<String, Object>> getAll() async => const {};

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    return false;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      true;
}

final class _FalseSetSharedPreferencesStore
    extends SharedPreferencesStorePlatform {
  _FalseSetSharedPreferencesStore(Map<String, Object> persistedValues)
    : _persistedValues = Map<String, Object>.from(persistedValues);

  final Map<String, Object> _persistedValues;
  final List<String> setKeys = [];

  @override
  Future<bool> clear() async {
    _persistedValues.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async =>
      Map<String, Object>.from(_persistedValues);

  @override
  Future<bool> remove(String key) async {
    _persistedValues.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    setKeys.add(key);
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
