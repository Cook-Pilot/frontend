import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
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
      recipeId: recipe.id,
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

  CookingSetupSnapshot buildSnapshot() {
    return CookingSetupSnapshot(
      recipeId: recipe.id,
      title: recipe.title,
      description: recipe.description,
      imageUrl: recipe.imageUrl,
      baseServings: recipe.baseServings,
      targetServings: 2,
      source: CookingRecipeSource.base,
      personalVersionId: null,
      ingredients: const [],
      steps: const [
        CookingSetupStep(
          stepIndex: 0,
          instruction: '첫 번째 단계를 진행하세요.',
          timerSeconds: 180,
          cautionNote: null,
          imageUrl: '',
        ),
      ],
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
    testWidgets('분으로 나누어지지 않는 단계 타이머도 정확한 초로 시작한다', (tester) async {
      const exactSecondsRecipe = Recipe(
        id: 'exact-seconds-recipe',
        title: '90초 타이머 레시피',
        description: '초 단위 타이머를 검증한다.',
        baseServings: 1,
        imageUrl: '',
        ingredients: <Ingredient>[],
        steps: <CookStep>[
          CookStep(
            stepIndex: 0,
            instruction: '90초 동안 조리하세요.',
            timerSeconds: 90,
            cautionNote: null,
            imageUrl: '',
          ),
        ],
        hasPersonalVersion: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CookSessionScreen(
            recipe: exactSecondsRecipe,
            servings: 1,
            alarm: SilentTimerAlarm(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('01:30'), findsOneWidget);
    });

    testWidgets('진입하면 현재 진행 상황을 저장한다', (tester) async {
      await pumpSession(tester);

      final saved = await store.load();
      expect(saved, isNotNull);
      expect(saved!.recipeId, recipe.id);
      expect(saved.recipeTitle, recipe.title);
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

    testWidgets('조리를 완료해도 후기 저장 전까지 저장본을 유지한다', (tester) async {
      await pumpSession(
        tester,
        restoredSession: buildSession(stepIndex: recipe.steps.length - 1),
      );

      await tester.tap(find.text('조리 완료'));
      await tester.pumpAndSettle();

      expect(await store.load(), isNotNull);
    });

    testWidgets('완료 후 전환 중 타이머가 만료돼도 저장본을 덮어쓰지 않는다', (tester) async {
      final restored = buildSession(
        stepIndex: recipe.steps.length - 1,
        timerStatus: 'running',
        timerRemainingMs: 400,
      );
      await pumpSession(tester, restoredSession: restored);
      final sessionIdBeforeCompletion = (await store.load())!.sessionId;

      await tester.tap(find.text('조리 완료'));
      // 전환 애니메이션 중에는 이전 화면 State와 타이머 콜백이 살아 있다.
      await tester.pump(const Duration(milliseconds: 50));
      // 타이머는 벽시계 기준이므로 실제 시간을 흘려 만료시킨다.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      final saved = await store.load();
      expect(saved, isNotNull);
      expect(saved!.sessionId, sessionIdBeforeCompletion);
    });
  });

  group('ReviewScreen 저장', () {
    testWidgets('후기 저장이 성공한 뒤에만 조리 세션을 정리한다', (tester) async {
      await store.save(buildSession());
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            setupSnapshot: buildSnapshot(),
            clientSessionId: '40000000-0000-0000-0000-000000000001',
            cookedAt: DateTime(2026, 7, 26),
            timerSecondsByStep: const {},
            reviewRepository: _FakeReviewRepository(),
          ),
        ),
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(await store.load(), isNull);
    });

    testWidgets('후기 저장에 실패하면 재시도할 조리 세션을 유지한다', (tester) async {
      await store.save(buildSession());
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            setupSnapshot: buildSnapshot(),
            clientSessionId: '40000000-0000-0000-0000-000000000001',
            cookedAt: DateTime(2026, 7, 26),
            timerSecondsByStep: const {},
            reviewRepository: _FakeReviewRepository(shouldFail: true),
          ),
        ),
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(await store.load(), isNotNull);
    });
  });
}

final class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository({this.shouldFail = false})
    : super(baseUrl: 'http://example.test');

  final bool shouldFail;

  @override
  Future<ReviewSaveResult> submit({
    required String clientSessionId,
    required DateTime cookedAt,
    required CookingSetupSnapshot snapshot,
    required int rating,
    required String comment,
    required String nextTimeNote,
  }) async {
    if (shouldFail) {
      throw const ReviewApiException('저장 실패');
    }
    return const ReviewSaveResult(
      id: '50000000-0000-0000-0000-000000000001',
      createdPersonalVersionId: null,
    );
  }
}
