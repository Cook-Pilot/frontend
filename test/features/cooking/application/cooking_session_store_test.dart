import 'dart:convert';

import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PersistedCookingSession buildSession({
    String sessionId = '40000000-0000-0000-0000-000000000001',
    String? recipeId = '10000000-0000-0000-0000-000000000001',
    String sessionStatus = 'cooking',
    String timerStatus = 'running',
    int timerRemainingMs = 3 * 60 * 1000,
    int savedAtEpochMs = 1000000,
    CookingSetupSnapshot? setupSnapshot,
    Map<int, int> timerSecondsByStep = const {1: 240},
  }) {
    return PersistedCookingSession(
      sessionId: sessionId,
      recipeId: recipeId,
      recipeTitle: '두부 조림',
      servings: 2,
      setupSnapshot: setupSnapshot,
      stepIndex: 2,
      sessionStatus: sessionStatus,
      timerOriginalMs: 4 * 60 * 1000,
      timerEffectiveMs: 5 * 60 * 1000,
      timerRemainingMs: timerRemainingMs,
      timerStatus: timerStatus,
      savedAtEpochMs: savedAtEpochMs,
      timerSecondsByStep: timerSecondsByStep,
    );
  }

  group('CookingSessionStore', () {
    const store = CookingSessionStore();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('저장한 세션을 그대로 다시 읽는다', () async {
      await store.save(buildSession());

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.sessionId, '40000000-0000-0000-0000-000000000001');
      expect(loaded.recipeId, '10000000-0000-0000-0000-000000000001');
      expect(loaded.recipeTitle, '두부 조림');
      expect(loaded.servings, 2);
      expect(loaded.stepIndex, 2);
      expect(loaded.sessionStatus, 'cooking');
      expect(loaded.timerRemainingMs, 3 * 60 * 1000);
      expect(loaded.timerSecondsByStep, {1: 240});
      expect(loaded.isResumable, isTrue);
    });

    test('기존 제목 전용 저장값도 하위 호환으로 읽는다', () async {
      await store.save(buildSession(recipeId: null));

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.recipeId, isNull);
      expect(loaded.recipeTitle, '두부 조림');
    });

    test('실행 스냅샷을 세션과 함께 저장하고 복원한다', () async {
      final snapshot = CookingSetupSnapshot(
        recipeId: '10000000-0000-0000-0000-000000000001',
        title: '두부 조림',
        description: '',
        imageUrl: '',
        baseServings: 1,
        targetServings: 2,
        source: CookingRecipeSource.base,
        personalVersionId: null,
        ingredients: const [
          CookingSetupIngredient(
            originalName: '두부',
            name: '두부',
            amount: 2,
            unit: '모',
            isRequired: true,
          ),
        ],
        steps: const [
          CookingSetupStep(
            stepIndex: 0,
            instruction: '두부를 부치세요.',
            timerSeconds: 120,
            cautionNote: null,
            imageUrl: '',
          ),
        ],
      );
      await store.save(buildSession(setupSnapshot: snapshot));

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.setupSnapshot, isNotNull);
      expect(loaded.setupSnapshot!.targetServings, 2);
      expect(loaded.setupSnapshot!.ingredients.single.amount, 2);
      expect(loaded.setupSnapshot!.steps.single.timerSeconds, 120);
    });

    test('실행 스냅샷만 손상되면 단계와 타이머 세션은 유지한다', () async {
      final json = buildSession().toJson();
      json['setupSnapshot'] = <String, Object?>{
        'schemaVersion': CookingSetupSnapshot.currentSchemaVersion + 1,
      };
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cookpilot.active_cooking_session.v1': jsonEncode(json),
      });

      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.setupSnapshot, isNull);
      expect(loaded.recipeId, '10000000-0000-0000-0000-000000000001');
      expect(loaded.stepIndex, 2);
      expect(loaded.timerRemainingMs, 3 * 60 * 1000);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cookpilot.active_cooking_session.v1'), isNotNull);
    });

    test('recipeId 타입이 손상된 저장값은 정리한다', () async {
      final json = buildSession().toJson();
      json['recipeId'] = 1234;
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cookpilot.active_cooking_session.v1': jsonEncode(json),
      });

      expect(await store.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cookpilot.active_cooking_session.v1'), isNull);
    });

    test('저장된 세션이 없으면 null을 돌려준다', () async {
      expect(await store.load(), isNull);
    });

    test('플랫폼 저장이 false면 이전 영속 세션을 캐시에 복원한다', () async {
      final persistedSession = buildSession(sessionStatus: 'paused');
      final platform = _FailingSetSharedPreferencesStore({
        _platformStorageKey: jsonEncode(persistedSession.toJson()),
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        failingStore.save(buildSession(sessionStatus: 'cooking')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '진행 중 조리 세션을 로컬에 저장하지 못했습니다.',
          ),
        ),
      );

      final restored = await failingStore.load();
      expect(restored, isNotNull);
      expect(restored!.sessionStatus, 'paused');
      expect(platform.setKeys, const [_platformStorageKey]);
      expect(platform.getAllCalls, 2);
    });

    test('플랫폼 저장 예외 뒤 이전 세션과 원래 stack을 복원한다', () async {
      final persistedSession = buildSession(sessionStatus: 'paused');
      final writeError = StateError('platform write failed');
      final writeStackTrace = StackTrace.fromString(
        'platform session write failure stack',
      );
      final platform = _FailingSetSharedPreferencesStore(
        {_platformStorageKey: jsonEncode(persistedSession.toJson())},
        writeError: writeError,
        writeStackTrace: writeStackTrace,
      );
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );
      Object? caughtError;
      StackTrace? caughtStackTrace;

      try {
        await failingStore.save(buildSession(sessionStatus: 'cooking'));
      } on Object catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
      }

      expect(caughtError, same(writeError));
      expect(caughtStackTrace.toString(), writeStackTrace.toString());
      final restored = await failingStore.load();
      expect(restored, isNotNull);
      expect(restored!.sessionStatus, 'paused');
      expect(platform.getAllCalls, 2);
    });

    for (final hasPreviousSession in [true, false]) {
      for (final writeThrows in [false, true]) {
        final previousState = hasPreviousSession ? '이전 세션이 있으면' : '이전 세션이 없으면';
        final failureMode = writeThrows ? '저장 예외' : '저장 false';

        test(
          '$failureMode 뒤 reload도 실패해도 $previousState cache와 최초 오류를 보존한다',
          () async {
            final previousSession = buildSession(sessionStatus: 'paused');
            final persistedValues = <String, Object>{
              if (hasPreviousSession)
                _platformStorageKey: jsonEncode(previousSession.toJson()),
            };
            final writeError = StateError('initial platform write failed');
            final writeStackTrace = StackTrace.fromString(
              'initial platform session write failure stack',
            );
            final reloadError = StateError('reload failed');
            final reloadStackTrace = StackTrace.fromString(
              'session reload failure stack',
            );
            final restoreError = StateError('cache restore failed');
            final restoreStackTrace = StackTrace.fromString(
              'session cache restore failure stack',
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
            final failingStore = CookingSessionStore(
              preferencesLoader: () async => preferences,
            );
            Object? caughtError;
            StackTrace? caughtStackTrace;

            try {
              await failingStore.save(buildSession(sessionStatus: 'cooking'));
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
                  '진행 중 조리 세션을 로컬에 저장하지 못했습니다.',
                ),
              );
              expect(caughtError, isNot(same(reloadError)));
              expect(caughtError, isNot(same(restoreError)));
              expect(
                caughtStackTrace.toString(),
                contains('cooking_session_store.dart'),
              );
            }

            final restored = await failingStore.load();
            if (hasPreviousSession) {
              expect(restored, isNotNull);
              expect(restored!.sessionStatus, 'paused');
            } else {
              expect(restored, isNull);
              expect(preferences.containsKey(_storageKey), isFalse);
            }
            expect(platform.getAllCalls, 2);
          },
        );
      }
    }

    test('저장소를 열지 못한 오류를 세션 없음으로 숨기지 않는다', () async {
      final failingStore = CookingSessionStore(
        preferencesLoader: () async {
          throw StateError('preferences unavailable');
        },
      );

      await expectLater(failingStore.load(), throwsStateError);
    });

    test('손상된 저장값은 null을 돌려주고 정리한다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cookpilot.active_cooking_session.v1': '{broken json',
      });

      expect(await store.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cookpilot.active_cooking_session.v1'), isNull);
    });

    test('손상값 remove가 false면 캐시를 복원해 다음 load가 다시 정리한다', () async {
      final platform = _FailingRemoveSharedPreferencesStore({
        _platformStorageKey: '{broken json',
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );

      expect(await failingStore.load(), isNull);
      expect(preferences.getString(_storageKey), '{broken json');
      expect(await failingStore.load(), isNull);

      expect(platform.removedKeys, const [
        _platformStorageKey,
        _platformStorageKey,
      ]);
      expect(platform.getAllCalls, 3);
    });

    test('손상값 remove 예외도 캐시를 복원해 다음 load가 다시 정리한다', () async {
      final platform = _FailingRemoveSharedPreferencesStore({
        _platformStorageKey: '{broken json',
      }, removeError: StateError('platform remove failed'));
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );

      expect(await failingStore.load(), isNull);
      expect(preferences.getString(_storageKey), '{broken json');
      expect(await failingStore.load(), isNull);

      expect(platform.removedKeys, const [
        _platformStorageKey,
        _platformStorageKey,
      ]);
      expect(platform.getAllCalls, 3);
    });

    for (final removeThrows in [false, true]) {
      final failureMode = removeThrows ? 'remove 예외' : 'remove false';

      test(
        '손상값 $failureMode 뒤 reload와 fallback도 실패하면 cache를 복원해 정리를 재시도한다',
        () async {
          final removeError = StateError('initial cleanup remove failed');
          final platform = _FailingRemoveSharedPreferencesStore(
            {_platformStorageKey: '{reload also fails'},
            removeError: removeThrows ? removeError : null,
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
          final failingStore = CookingSessionStore(
            preferencesLoader: () async => preferences,
          );

          expect(await failingStore.load(), isNull);
          expect(preferences.getString(_storageKey), '{reload also fails');
          expect(await failingStore.load(), isNull);
          expect(preferences.getString(_storageKey), '{reload also fails');

          expect(platform.removedKeys, const [
            _platformStorageKey,
            _platformStorageKey,
          ]);
          expect(platform.setKeys, const [
            _platformStorageKey,
            _platformStorageKey,
          ]);
          expect(platform.getAllCalls, 3);
        },
      );
    }

    test('clear 후에는 세션이 남지 않는다', () async {
      await store.save(buildSession());
      await store.clear();

      expect(await store.load(), isNull);
    });

    test('플랫폼 remove가 false면 실제 세션을 캐시에 복원하고 실패를 전달한다', () async {
      final persistedSession = buildSession(sessionStatus: 'paused');
      final platform = _FailingRemoveSharedPreferencesStore({
        _platformStorageKey: jsonEncode(persistedSession.toJson()),
      });
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );

      await expectLater(
        failingStore.clear(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '진행 중 조리 세션을 로컬에서 정리하지 못했습니다.',
          ),
        ),
      );

      final restored = await failingStore.load();
      expect(restored, isNotNull);
      expect(restored!.sessionStatus, 'paused');
      expect(platform.removedKeys, const [_platformStorageKey]);
      expect(platform.getAllCalls, 2);
    });

    test('플랫폼 remove 예외 뒤 실제 세션과 원래 stack을 복원한다', () async {
      final persistedSession = buildSession(sessionStatus: 'paused');
      final removeError = StateError('platform remove failed');
      final removeStackTrace = StackTrace.fromString(
        'platform session remove failure stack',
      );
      final platform = _FailingRemoveSharedPreferencesStore(
        {_platformStorageKey: jsonEncode(persistedSession.toJson())},
        removeError: removeError,
        removeStackTrace: removeStackTrace,
      );
      final originalPlatform = SharedPreferencesStorePlatform.instance;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = originalPlatform;
      });
      SharedPreferencesStorePlatform.instance = platform;
      final preferences = await SharedPreferences.getInstance();
      final failingStore = CookingSessionStore(
        preferencesLoader: () async => preferences,
      );
      Object? caughtError;
      StackTrace? caughtStackTrace;

      try {
        await failingStore.clear();
      } on Object catch (error, stackTrace) {
        caughtError = error;
        caughtStackTrace = stackTrace;
      }

      expect(caughtError, same(removeError));
      expect(caughtStackTrace.toString(), removeStackTrace.toString());
      final restored = await failingStore.load();
      expect(restored, isNotNull);
      expect(restored!.sessionStatus, 'paused');
      expect(platform.removedKeys, const [_platformStorageKey]);
      expect(platform.getAllCalls, 2);
    });

    for (final hasPreviousSession in [true, false]) {
      for (final removeThrows in [false, true]) {
        final previousState = hasPreviousSession ? '이전 세션이 있으면' : '이전 세션이 없으면';
        final failureMode = removeThrows ? 'remove 예외' : 'remove false';

        test(
          'clear $failureMode 뒤 reload도 실패해도 $previousState cache와 최초 오류를 보존한다',
          () async {
            final previousSession = buildSession(sessionStatus: 'paused');
            final persistedValues = <String, Object>{
              if (hasPreviousSession)
                _platformStorageKey: jsonEncode(previousSession.toJson()),
            };
            final removeError = StateError('initial platform remove failed');
            final removeStackTrace = StackTrace.fromString(
              'initial platform session remove failure stack',
            );
            final reloadError = StateError('reload failed');
            final reloadStackTrace = StackTrace.fromString(
              'session reload failure stack',
            );
            final restoreError = StateError('cache restore failed');
            final restoreStackTrace = StackTrace.fromString(
              'session cache restore failure stack',
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
            final failingStore = CookingSessionStore(
              preferencesLoader: () async => preferences,
            );
            Object? caughtError;
            StackTrace? caughtStackTrace;

            try {
              await failingStore.clear();
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
                  '진행 중 조리 세션을 로컬에서 정리하지 못했습니다.',
                ),
              );
              expect(caughtError, isNot(same(reloadError)));
              expect(caughtError, isNot(same(restoreError)));
              expect(
                caughtStackTrace.toString(),
                contains('cooking_session_store.dart'),
              );
            }

            final restored = await failingStore.load();
            if (hasPreviousSession) {
              expect(restored, isNotNull);
              expect(restored!.sessionStatus, 'paused');
            } else {
              expect(restored, isNull);
              expect(preferences.containsKey(_storageKey), isFalse);
            }
            expect(platform.getAllCalls, 2);
          },
        );
      }
    }
  });

  group('PersistedCookingSession.timerSnapshotAt', () {
    test('실행 중이던 타이머는 저장 후 흐른 벽시계 시간을 차감한다', () {
      final session = buildSession(savedAtEpochMs: 1000000);
      final now = DateTime.fromMillisecondsSinceEpoch(
        1000000 + 60 * 1000, // 저장 후 1분 경과
      );

      final snapshot = session.timerSnapshotAt(now);

      expect(snapshot.status, TimerStatus.running);
      expect(snapshot.remaining, const Duration(minutes: 2));
      expect(snapshot.effectiveDuration, const Duration(minutes: 5));
    });

    test('앱이 오래 꺼져 있었으면 남은 시간이 음수가 된다(복원 시 종료 처리)', () {
      final session = buildSession(savedAtEpochMs: 1000000);
      final now = DateTime.fromMillisecondsSinceEpoch(
        1000000 + 10 * 60 * 1000, // 저장 후 10분 경과
      );

      final snapshot = session.timerSnapshotAt(now);

      expect(snapshot.remaining.isNegative, isTrue);
    });

    test('일시정지된 타이머는 흐른 시간을 차감하지 않는다', () {
      final session = buildSession(
        timerStatus: 'paused',
        savedAtEpochMs: 1000000,
      );
      final now = DateTime.fromMillisecondsSinceEpoch(
        1000000 + 60 * 60 * 1000, // 저장 후 1시간 경과
      );

      final snapshot = session.timerSnapshotAt(now);

      expect(snapshot.status, TimerStatus.paused);
      expect(snapshot.remaining, const Duration(minutes: 3));
    });

    test('시스템 시각이 과거로 돌아가도 남은 시간이 늘어나지 않는다', () {
      final session = buildSession(savedAtEpochMs: 1000000);
      final now = DateTime.fromMillisecondsSinceEpoch(
        1000000 - 60 * 1000, // 저장 시각보다 과거
      );

      final snapshot = session.timerSnapshotAt(now);

      expect(snapshot.remaining, const Duration(minutes: 3));
    });

    test('알 수 없는 타이머 상태는 idle로 복원한다', () {
      final session = buildSession(timerStatus: 'exploded');

      final snapshot = session.timerSnapshotAt(
        DateTime.fromMillisecondsSinceEpoch(2000000),
      );

      expect(snapshot.status, TimerStatus.idle);
    });
  });

  group('PersistedCookingSession.isResumable', () {
    test('cooking과 paused만 복원 대상이다', () {
      expect(buildSession(sessionStatus: 'cooking').isResumable, isTrue);
      expect(buildSession(sessionStatus: 'paused').isResumable, isTrue);
      expect(buildSession(sessionStatus: 'review').isResumable, isFalse);
      expect(buildSession(sessionStatus: 'completed').isResumable, isFalse);
      expect(buildSession(sessionStatus: 'aborted').isResumable, isFalse);
    });
  });
}

const _storageKey = 'cookpilot.active_cooking_session.v1';
const _platformStorageKey = 'flutter.$_storageKey';

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
