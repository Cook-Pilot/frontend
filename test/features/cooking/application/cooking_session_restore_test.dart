import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = CookingSessionStore();

  const recipe = Recipe(
    id: 'cooking-session-test-recipe',
    title: '조리 세션 테스트 레시피',
    description: '로컬 세션 저장과 복원을 검증한다.',
    baseServings: 2,
    imageUrl: '',
    ingredients: <Ingredient>[],
    steps: <CookStep>[
      CookStep(
        stepIndex: 0,
        instruction: '첫 번째 단계를 진행하세요.',
        timerSeconds: 180,
        cautionNote: null,
        imageUrl: '',
      ),
      CookStep(
        stepIndex: 1,
        instruction: '두 번째 단계를 진행하세요.',
        timerSeconds: 180,
        cautionNote: null,
        imageUrl: '',
      ),
      CookStep(
        stepIndex: 2,
        instruction: '마지막 단계를 진행하세요.',
        timerSeconds: 180,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
    hasPersonalVersion: false,
  );

  PersistedCookingSession buildSession({
    int stepIndex = 2,
    String timerStatus = 'paused',
    int timerRemainingMs = 90 * 1000,
  }) {
    return PersistedCookingSession(
      recipeTitle: recipe.title,
      servings: 2,
      stepIndex: stepIndex,
      sessionStatus: 'cooking',
      timerOriginalMs: 3 * 60 * 1000,
      timerEffectiveMs: 3 * 60 * 1000,
      timerRemainingMs: timerRemainingMs,
      timerStatus: timerStatus,
      savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> pumpSession(
    WidgetTester tester, {
    PersistedCookingSession? restoredSession,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CookSessionScreen(
          recipe: recipe,
          servings: 2,
          restoredSession: restoredSession,
          alarm: SilentTimerAlarm(),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('CookSessionScreen 복원', () {
    testWidgets('저장된 단계에서 세션을 다시 시작한다', (tester) async {
      await pumpSession(tester, restoredSession: buildSession(stepIndex: 2));

      expect(find.text('3 / ${recipe.steps.length} 단계'), findsOneWidget);
      expect(find.text(recipe.steps[2].title), findsOneWidget);
    });

    testWidgets('범위 밖 단계는 마지막 단계로 보정한다', (tester) async {
      await pumpSession(tester, restoredSession: buildSession(stepIndex: 99));

      expect(
        find.text('${recipe.steps.length} / ${recipe.steps.length} 단계'),
        findsOneWidget,
      );
    });

    testWidgets('일시정지된 타이머의 남은 시간을 되살린다', (tester) async {
      await pumpSession(
        tester,
        restoredSession: buildSession(timerRemainingMs: 90 * 1000),
      );

      expect(find.text('01:30'), findsOneWidget);
      // paused 상태 복원이므로 토글 라벨은 "계속"이어야 한다.
      expect(find.text('계속'), findsOneWidget);
    });
  });

  group('CookSessionScreen 저장', () {
    testWidgets('진입하면 현재 진행 상황을 저장한다', (tester) async {
      await pumpSession(tester);

      final saved = await store.load();
      expect(saved, isNotNull);
      expect(saved!.recipeTitle, recipe.title);
      expect(saved.stepIndex, 0);
      expect(saved.isResumable, isTrue);
    });

    testWidgets('다음 단계로 넘어가면 단계를 갱신해 저장한다', (tester) async {
      await pumpSession(tester);

      await tester.tap(find.text('다음 단계'));
      await tester.pump();

      final saved = await store.load();
      expect(saved!.stepIndex, 1);
    });

    testWidgets('조리를 완료하면 저장본을 정리한다', (tester) async {
      await pumpSession(
        tester,
        restoredSession: buildSession(stepIndex: recipe.steps.length - 1),
      );

      await tester.tap(find.text('조리 완료'));
      await tester.pumpAndSettle();

      expect(await store.load(), isNull);
    });

    testWidgets('완료 후 전환 중 타이머가 만료돼도 저장본을 되살리지 않는다', (tester) async {
      await pumpSession(
        tester,
        restoredSession: buildSession(
          stepIndex: recipe.steps.length - 1,
          timerStatus: 'running',
          timerRemainingMs: 400,
        ),
      );

      await tester.tap(find.text('조리 완료'));
      // 전환 애니메이션 중에는 이전 화면 State와 타이머 콜백이 살아 있다.
      await tester.pump(const Duration(milliseconds: 50));
      // 타이머는 벽시계 기준이므로 실제 시간을 흘려 만료시킨다.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(await store.load(), isNull);
    });
  });
}
