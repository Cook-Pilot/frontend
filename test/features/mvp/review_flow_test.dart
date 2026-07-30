import 'dart:async';

import 'package:cookpilot/features/cooking/application/cooking_ports.dart';
import 'package:cookpilot/features/cooking/application/cooking_session_store.dart';
import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:cookpilot/features/review/data/personal_version_approval_api.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('조리 완료 전환', () {
    testWidgets('pending draft 저장 실패 뒤 같은 완료 동작을 재시도할 수 있다', (tester) async {
      final pendingStore = _FakePendingReviewDraftStore(
        saveFailuresRemaining: 1,
      );

      await _pumpLastCookingStep(tester, pendingStore: pendingStore);
      await tester.tap(find.text('조리 완료'));
      await _pumpAsyncWork(tester);

      expect(pendingStore.saveAttempts, hasLength(1));
      final firstAttempt = pendingStore.saveAttempts.single;
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      expect(find.byKey(const Key('cooking-completion-error')), findsOneWidget);
      expect(find.byType(ReviewScreen), findsNothing);
      expect(await const CookingSessionStore().load(), isNotNull);

      await tester.tap(find.text('조리 완료'));
      await _pumpAsyncWork(tester);
      final persisted = await pendingStore.load();

      final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      expect(pendingStore.saveAttempts, hasLength(2));
      final retryAttempt = pendingStore.saveAttempts.last;
      expect(persisted, isNotNull);
      expect(review.initialDraft.clientSessionId, persisted!.clientSessionId);
      expect(review.initialDraft.cookedAt, persisted.cookedAt);
      expect(retryAttempt.clientSessionId, firstAttempt.clientSessionId);
      expect(retryAttempt.cookedAt, firstAttempt.cookedAt);
      expect(
        retryAttempt.setupSnapshot.toJson(),
        firstAttempt.setupSnapshot.toJson(),
      );
      expect(await pendingStore.load(), isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpAsyncWork(tester);
      await pendingStore.load();
    });

    testWidgets('완료 초안 저장도 실패하면 active 세션 저장을 강제로 다시 시도한다', (tester) async {
      final pendingStore = _FakePendingReviewDraftStore(
        saveFailuresRemaining: 1,
      );
      final activeStore = _FakeCookingSessionStore(saveFailuresRemaining: 1);
      await _pumpLastCookingStep(
        tester,
        pendingStore: pendingStore,
        cookingSessionStore: activeStore,
      );
      await _pumpAsyncWork(tester);
      expect(activeStore.saveAttempts, hasLength(1));
      expect(activeStore.storedSession, isNull);

      await tester.tap(find.text('조리 완료'));
      await _pumpAsyncWork(tester);

      expect(find.byType(ReviewScreen), findsNothing);
      expect(activeStore.saveAttempts, hasLength(2));
      expect(activeStore.storedSession, isNotNull);
      expect(
        activeStore.saveAttempts.last.sessionId,
        activeStore.saveAttempts.first.sessionId,
      );
    });

    testWidgets('pending draft 저장이 끝나기 전에는 후기 화면으로 이동하지 않는다', (tester) async {
      final saveGate = Completer<void>();
      final pendingStore = _FakePendingReviewDraftStore(saveGate: saveGate);

      await _pumpLastCookingStep(tester, pendingStore: pendingStore);
      await tester.tap(find.text('조리 완료'));
      await tester.pump();

      expect(find.text('완료 저장 중'), findsOneWidget);
      expect(find.byType(ReviewScreen), findsNothing);
      expect(await const CookingSessionStore().load(), isNotNull);

      saveGate.complete();
      await _pumpAsyncWork(tester);

      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(await pendingStore.load(), isNotNull);
      expect(await const CookingSessionStore().load(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpAsyncWork(tester);
      await pendingStore.load();
    });

    testWidgets('완료 초안을 고정한 뒤 저장 중에는 조리 문맥 변경을 잠근다', (tester) async {
      final saveGate = Completer<void>();
      final pendingStore = _FakePendingReviewDraftStore(saveGate: saveGate);
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpLastCookingStep(
        tester,
        pendingStore: pendingStore,
        recipe: _timedRecipe,
      );

      await tester.tap(find.text('조리 완료'));
      await tester.pump();

      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '1분 추가'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('voice-input-toggle')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.close_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<PopScope>(
              find.byKey(const Key('cooking-completion-pop-scope')),
            )
            .canPop,
        isFalse,
      );

      saveGate.complete();
      await _pumpAsyncWork(tester);
      expect(find.byType(ReviewScreen), findsOneWidget);
    });
  });

  group('후기 draft 복구', () {
    testWidgets('입력값을 300ms 뒤 자동 저장하고 initialDraft에서 복원한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      await _pumpReview(tester, store: store);

      await tester.tap(find.byIcon(Icons.star_rounded).at(2));
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '겉은 바삭하고 속은 촉촉했어요.',
      );
      await tester.enterText(
        find.byKey(const Key('review-next-time-field')),
        '다음에는 소금을 조금 줄이기',
      );
      await tester.tap(find.byKey(const Key('personal-version-opt-in')));
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();

      final restored = await store.load();
      expect(restored, isNotNull);
      expect(restored!.rating, 3);
      expect(restored.comment, '겉은 바삭하고 속은 촉촉했어요.');
      expect(restored.nextTimeNote, '다음에는 소금을 조금 줄이기');
      expect(restored.approvedPersonalVersionCreation, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: ReviewScreen(
            initialDraft: restored,
            pendingReviewDraftStore: store,
            reviewRepository: _FakeReviewRepository(),
            personalVersionApprovalGateway: _FakeApprovalGateway(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3 / 5'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('review-comment-field')))
            .controller!
            .text,
        '겉은 바삭하고 속은 촉촉했어요.',
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('personal-version-opt-in')),
            )
            .value,
        isTrue,
      );
    });

    testWidgets('후기와 다음 메모를 Unicode code point 기준으로 제한한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      await _pumpReview(tester, store: store);
      final longComment = List.filled(1001, '🍳').join();
      final longNote = List.filled(501, '🍚').join();

      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        longComment,
      );
      await tester.enterText(
        find.byKey(const Key('review-next-time-field')),
        longNote,
      );
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();

      final commentField = tester.widget<TextField>(
        find.byKey(const Key('review-comment-field')),
      );
      final noteField = tester.widget<TextField>(
        find.byKey(const Key('review-next-time-field')),
      );
      expect(commentField.controller!.text.runes.length, 1000);
      expect(noteField.controller!.text.runes.length, 500);
      final saved = await store.load();
      expect(saved!.comment.runes.length, 1000);
      expect(saved.nextTimeNote.runes.length, 500);
    });

    testWidgets('앱이 백그라운드로 가면 debounce 전에 최신 입력을 즉시 저장한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      await _pumpReview(tester, store: store);

      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '백그라운드 직전 입력',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _pumpAsyncWork(tester);

      final saved = await store.load();
      expect(saved, isNotNull);
      expect(saved!.comment, '백그라운드 직전 입력');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('화면이 dispose되면 debounce 전 최신 입력을 저장한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      await _pumpReview(tester, store: store);
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '화면 종료 직전 입력',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpAsyncWork(tester);

      expect((await store.load())?.comment, '화면 종료 직전 입력');
    });

    testWidgets('최대 길이의 중간 삽입을 거절해 기존 마지막 글자를 보존한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      final original = List.filled(1000, '가').join();
      await _pumpReview(
        tester,
        store: store,
        initialDraft: _draft(comment: original),
      );
      final finder = find.byKey(const Key('review-comment-field'));
      await tester.tap(finder);
      final controller = tester.widget<TextField>(finder).controller!;
      controller.selection = const TextSelection.collapsed(offset: 500);

      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '${original.substring(0, 500)}나${original.substring(500)}',
          selection: const TextSelection.collapsed(offset: 501),
          composing: const TextRange(start: 500, end: 501),
        ),
      );
      await tester.pump();

      expect(controller.text, original);
      expect(controller.text.runes.length, 1000);
      expect(controller.text.endsWith('가'), isTrue);
    });
  });

  group('후기와 개인 버전 저장 순서', () {
    testWidgets('local draft 저장 실패 시 후기 API를 호출하지 않는다', (tester) async {
      final reviewRepository = _FakeReviewRepository();
      final failingStore = _FakePendingReviewDraftStore(failAllSaves: true);
      await _pumpReview(
        tester,
        store: failingStore,
        reviewRepository: reviewRepository,
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 0);
      expect(find.byKey(const Key('review-draft-save-error')), findsOneWidget);
      expect(find.text('조리 기록 저장'), findsOneWidget);
    });

    testWidgets('기본값인 미승인 상태에서는 후기만 저장한다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      final reviewRepository = _FakeReviewRepository();
      final approvalGateway = _FakeApprovalGateway();
      await _pumpReview(
        tester,
        store: store,
        reviewRepository: reviewRepository,
        approvalGateway: approvalGateway,
      );

      final optIn = tester.widget<SwitchListTile>(
        find.byKey(const Key('personal-version-opt-in')),
      );
      expect(optIn.value, isFalse);

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 1);
      expect(approvalGateway.calls, 0);
      expect(await store.load(), isNull);
      expect(find.text('후기만 저장했어요. 개인 버전은 만들지 않았어요.'), findsOneWidget);
    });

    testWidgets('후기 API 실패 시 draft를 유지하고 같은 clientSessionId로 재시도한다', (
      tester,
    ) async {
      final store = _FakePendingReviewDraftStore();
      final reviewRepository = _FakeReviewRepository(shouldFail: true);
      await _pumpReview(
        tester,
        store: store,
        reviewRepository: reviewRepository,
      );
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '서버 실패 뒤에도 남을 후기',
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 1);
      final pendingAfterFailure = await store.load();
      expect(pendingAfterFailure, isNotNull);
      expect(pendingAfterFailure!.comment, '서버 실패 뒤에도 남을 후기');
      expect(find.text('저장 실패'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('review-comment-field')))
            .enabled,
        isTrue,
      );

      reviewRepository.shouldFail = false;
      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 2);
      expect(reviewRepository.clientSessionIds, const [
        '40000000-0000-0000-0000-000000000002',
        '40000000-0000-0000-0000-000000000002',
      ]);
      expect(await store.load(), isNull);
    });

    for (final approvalResult in <PersonalVersionApprovalResult>[
      const PersonalVersionCreated(),
      const PersonalVersionNoChange(),
    ]) {
      final resultLabel = approvalResult is PersonalVersionCreated
          ? '201 생성'
          : '204 변경 없음';
      testWidgets('명시적으로 승인하면 후기 뒤 개인 버전을 호출하고 $resultLabel을 성공 처리한다', (
        tester,
      ) async {
        final store = _FakePendingReviewDraftStore();
        final reviewRepository = _FakeReviewRepository();
        final approvalGateway = _FakeApprovalGateway(result: approvalResult);
        await _pumpReview(
          tester,
          store: store,
          reviewRepository: reviewRepository,
          approvalGateway: approvalGateway,
        );

        await tester.tap(find.byKey(const Key('personal-version-opt-in')));
        await tester.pump();
        await tester.tap(find.text('조리 기록 저장'));
        await tester.pumpAndSettle();

        expect(reviewRepository.calls, 1);
        expect(approvalGateway.calls, 1);
        expect(approvalGateway.reviewIds, const [
          '50000000-0000-0000-0000-000000000001',
        ]);
        expect(approvalGateway.transcripts, const [null]);
        expect(await store.load(), isNull);
        expect(find.text('조리 기록을 저장했어요'), findsOneWidget);
        expect(
          find.text(
            approvalResult is PersonalVersionCreated
                ? '후기와 개인 버전을 저장했어요.'
                : '적용할 변경이 없어 개인 버전은 만들지 않았어요.',
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('개인 버전 실패 재시도는 이미 저장된 후기를 다시 만들지 않는다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      final reviewRepository = _FakeReviewRepository();
      final approvalGateway = _FakeApprovalGateway(failuresRemaining: 1);
      await _pumpReview(
        tester,
        store: store,
        reviewRepository: reviewRepository,
        approvalGateway: approvalGateway,
      );

      await tester.tap(find.byKey(const Key('personal-version-opt-in')));
      await tester.pump();
      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 1);
      expect(approvalGateway.calls, 1);
      expect(await store.load(), isNotNull);
      expect(
        find.textContaining('후기는 저장했지만 개인 버전을 만들지 못했습니다.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('review-comment-field')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('personal-version-opt-in')),
            )
            .onChanged,
        isNull,
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 1);
      expect(approvalGateway.calls, 2);
      expect(await store.load(), isNull);
      expect(find.text('조리 기록을 저장했어요'), findsOneWidget);
    });

    testWidgets('최종 저장 뒤 늦은 debounce가 pending draft를 되살리지 않는다', (tester) async {
      final store = _FakePendingReviewDraftStore();
      await _pumpReview(tester, store: store);

      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '저장 직전에 입력한 후기',
      );
      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(await store.load(), isNull);
    });

    testWidgets('진행 중 autosave와 lifecycle flush가 최종 clear 뒤 draft를 되살리지 않는다', (
      tester,
    ) async {
      final store = _QueuedPendingReviewDraftStore();
      final reviewRepository = _FakeReviewRepository();
      await _pumpReview(
        tester,
        store: store,
        reviewRepository: reviewRepository,
      );
      await tester.enterText(
        find.byKey(const Key('review-comment-field')),
        '저장 경합 중 최신 후기',
      );
      await tester.pump(const Duration(milliseconds: 301));
      expect(store.firstSaveEntered.isCompleted, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.tap(find.text('조리 기록 저장'));
      await tester.pump();

      store.releaseFirstSave.complete();
      await tester.pumpAndSettle();
      expect(reviewRepository.calls, 1);
      expect(await store.load(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpAsyncWork(tester);
      expect(await store.load(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('active session cleanup 실패는 서버 저장 실패와 구분해 안내한다', (
      tester,
    ) async {
      final store = _FakePendingReviewDraftStore();
      final activeStore = _FakeCookingSessionStore(failClear: true);
      final reviewRepository = _FakeReviewRepository();
      await _pumpReview(
        tester,
        store: store,
        reviewRepository: reviewRepository,
        cookingSessionStore: activeStore,
      );

      await tester.tap(find.text('조리 기록 저장'));
      await tester.pumpAndSettle();

      expect(reviewRepository.calls, 1);
      expect(find.text('조리 기록을 저장했어요'), findsOneWidget);
      expect(find.text('기록 저장은 완료됐어요'), findsOneWidget);
      expect(find.textContaining('조리 세션 정리를 완료하지 못해'), findsOneWidget);
      expect(find.text('저장하지 못했어요'), findsNothing);
      expect(await store.load(), isNull);
    });
  });
}

const _recipe = Recipe(
  id: '10000000-0000-0000-0000-000000000092',
  title: 'F9 후기 흐름 테스트',
  description: '완료와 후기 저장 순서를 검증한다.',
  baseServings: 2,
  imageUrl: '',
  ingredients: <Ingredient>[],
  steps: <CookStep>[
    CookStep(
      stepIndex: 0,
      instruction: '한 단계를 조리한다.',
      timerSeconds: 0,
      cautionNote: null,
      imageUrl: '',
    ),
  ],
  hasPersonalVersion: false,
);

const _timedRecipe = Recipe(
  id: '10000000-0000-0000-0000-000000000093',
  title: 'F9 완료 잠금 테스트',
  description: '완료 저장 중 조리 문맥 잠금을 검증한다.',
  baseServings: 2,
  imageUrl: '',
  ingredients: <Ingredient>[],
  steps: <CookStep>[
    CookStep(
      stepIndex: 0,
      instruction: '1분 동안 조리한다.',
      timerSeconds: 60,
      cautionNote: null,
      imageUrl: '',
    ),
  ],
  hasPersonalVersion: false,
);

CookingSetupSnapshot _snapshot() {
  return CookingSetupSnapshot(
    recipeId: '10000000-0000-0000-0000-000000000092',
    title: 'F9 후기 흐름 테스트',
    description: '완료와 후기 저장 순서를 검증한다.',
    imageUrl: '',
    baseServings: 2,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: <CookingSetupIngredient>[],
    steps: <CookingSetupStep>[
      CookingSetupStep(
        stepIndex: 0,
        instruction: '한 단계를 조리한다.',
        timerSeconds: 0,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
  );
}

PendingReviewDraft _draft({
  int rating = 5,
  String comment = '',
  String nextTimeNote = '',
  bool approved = false,
}) {
  return PendingReviewDraft(
    clientSessionId: '40000000-0000-0000-0000-000000000002',
    cookedAt: DateTime.utc(2026, 7, 30, 9),
    setupSnapshot: _snapshot(),
    timerSecondsByStep: const <int, int>{},
    rating: rating,
    comment: comment,
    nextTimeNote: nextTimeNote,
    approvedPersonalVersionCreation: approved,
  );
}

Future<void> _pumpLastCookingStep(
  WidgetTester tester, {
  required PendingReviewDraftGateway pendingStore,
  CookingSessionGateway? cookingSessionStore,
  Recipe recipe = _recipe,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CookSessionScreen(
        recipe: recipe,
        servings: 2,
        setupSnapshot: _snapshot(),
        pendingReviewDraftStore: pendingStore,
        cookingSessionStore: cookingSessionStore,
        alarm: SilentTimerAlarm(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  for (var i = 0; i < 5; i += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required PendingReviewDraftGateway store,
  _FakeReviewRepository? reviewRepository,
  _FakeApprovalGateway? approvalGateway,
  CookingSessionGateway? cookingSessionStore,
  PendingReviewDraft? initialDraft,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ReviewScreen(
        initialDraft: initialDraft ?? _draft(),
        pendingReviewDraftStore: store,
        reviewRepository: reviewRepository ?? _FakeReviewRepository(),
        personalVersionApprovalGateway:
            approvalGateway ?? _FakeApprovalGateway(),
        cookingSessionStore: cookingSessionStore,
      ),
    ),
  );
  await tester.pump();
}

final class _FakeCookingSessionStore implements CookingSessionGateway {
  _FakeCookingSessionStore({
    this.saveFailuresRemaining = 0,
    this.failClear = false,
  });

  int saveFailuresRemaining;
  final bool failClear;
  final List<PersistedCookingSession> saveAttempts =
      <PersistedCookingSession>[];
  PersistedCookingSession? storedSession;

  @override
  Future<void> save(PersistedCookingSession session) async {
    saveAttempts.add(session);
    if (saveFailuresRemaining > 0) {
      saveFailuresRemaining -= 1;
      throw StateError('active session save unavailable');
    }
    storedSession = session;
  }

  @override
  Future<PersistedCookingSession?> load() async => storedSession;

  @override
  Future<void> clear() async {
    if (failClear) {
      throw StateError('active session cleanup unavailable');
    }
    storedSession = null;
  }
}

final class _QueuedPendingReviewDraftStore
    implements PendingReviewDraftGateway {
  final Completer<void> firstSaveEntered = Completer<void>();
  final Completer<void> releaseFirstSave = Completer<void>();
  Future<void> _operationTail = Future<void>.value();
  PendingReviewDraft? _storedDraft;
  int _saveCalls = 0;

  @override
  Future<void> save(PendingReviewDraft draft) {
    return _serialize(() async {
      _saveCalls += 1;
      if (_saveCalls == 1) {
        firstSaveEntered.complete();
        await releaseFirstSave.future;
      }
      _storedDraft = draft;
    });
  }

  @override
  Future<PendingReviewDraft?> load() {
    return _serialize(() async => _storedDraft);
  }

  @override
  Future<void> clear() {
    return _serialize(() async {
      _storedDraft = null;
    });
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previous = _operationTail;
    final result = (() async {
      try {
        await previous;
      } on Object {
        // 앞선 작업 실패가 다음 작업을 막지 않는다.
      }
      return operation();
    })();
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

final class _FakePendingReviewDraftStore implements PendingReviewDraftGateway {
  _FakePendingReviewDraftStore({
    this.saveGate,
    this.saveFailuresRemaining = 0,
    this.failAllSaves = false,
  });

  final Completer<void>? saveGate;
  int saveFailuresRemaining;
  final bool failAllSaves;
  final List<PendingReviewDraft> saveAttempts = <PendingReviewDraft>[];
  PendingReviewDraft? _storedDraft;

  @override
  Future<void> save(PendingReviewDraft draft) async {
    saveAttempts.add(draft);
    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
    if (failAllSaves || saveFailuresRemaining > 0) {
      if (saveFailuresRemaining > 0) {
        saveFailuresRemaining -= 1;
      }
      throw StateError('temporary local failure');
    }
    _storedDraft = draft;
  }

  @override
  Future<PendingReviewDraft?> load() async => _storedDraft;

  @override
  Future<void> clear() async {
    _storedDraft = null;
  }
}

final class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository({this.shouldFail = false})
    : super(baseUrl: 'http://example.test');

  bool shouldFail;
  int calls = 0;
  final List<String> clientSessionIds = <String>[];

  @override
  Future<ReviewSaveResult> submit({
    required String clientSessionId,
    required DateTime cookedAt,
    required CookingSetupSnapshot snapshot,
    required int rating,
    required String comment,
    required String nextTimeNote,
  }) async {
    calls += 1;
    clientSessionIds.add(clientSessionId);
    if (shouldFail) {
      throw const ReviewApiException('저장 실패');
    }
    return const ReviewSaveResult(
      id: '50000000-0000-0000-0000-000000000001',
      createdPersonalVersionId: null,
    );
  }
}

final class _FakeApprovalGateway implements PersonalVersionApprovalGateway {
  _FakeApprovalGateway({
    this.result = const PersonalVersionCreated(),
    this.failuresRemaining = 0,
  });

  final PersonalVersionApprovalResult result;
  int failuresRemaining;
  int calls = 0;
  final List<String> reviewIds = <String>[];
  final List<String?> transcripts = <String?>[];

  @override
  Future<PersonalVersionApprovalResult> createFromApprovedReview({
    required String reviewId,
    required CookingSetupSnapshot snapshot,
    String? cookingTranscript,
  }) async {
    calls += 1;
    reviewIds.add(reviewId);
    transcripts.add(cookingTranscript);
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw const PersonalVersionApprovalApiException('개인 버전 저장 실패');
    }
    return result;
  }
}
