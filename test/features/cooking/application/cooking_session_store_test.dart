import 'dart:convert';

import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/cooking/domain/cooking_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PersistedCookingSession buildSession({
    String? recipeId = '10000000-0000-0000-0000-000000000001',
    String sessionStatus = 'cooking',
    String timerStatus = 'running',
    int timerRemainingMs = 3 * 60 * 1000,
    int savedAtEpochMs = 1000000,
    CookingSetupSnapshot? setupSnapshot,
  }) {
    return PersistedCookingSession(
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
      expect(loaded!.recipeId, '10000000-0000-0000-0000-000000000001');
      expect(loaded.recipeTitle, '두부 조림');
      expect(loaded.servings, 2);
      expect(loaded.stepIndex, 2);
      expect(loaded.sessionStatus, 'cooking');
      expect(loaded.timerRemainingMs, 3 * 60 * 1000);
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

    test('손상된 저장값은 null을 돌려주고 정리한다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'cookpilot.active_cooking_session.v1': '{broken json',
      });

      expect(await store.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cookpilot.active_cooking_session.v1'), isNull);
    });

    test('clear 후에는 세션이 남지 않는다', () async {
      await store.save(buildSession());
      await store.clear();

      expect(await store.load(), isNull);
    });
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
