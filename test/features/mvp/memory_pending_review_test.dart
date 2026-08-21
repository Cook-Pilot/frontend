import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

/// 쓰다 만 후기는 조리가 끝난 뒤에 남는 일이라 홈이 아니라 기록 탭에 있다.
void main() {
  setUp(signInForTest);
  tearDown(resetAuthForTest);

  testWidgets('후기 카드를 누르면 저장된 초안 객체를 그대로 후기 화면에 전달한다', (tester) async {
    final draft = _buildDraft();
    PendingReviewDraft? receivedDraft;

    await _pumpMemory(
      tester,
      pendingReviewDraftLoader: () async => draft,
      reviewScreenBuilder: (initialDraft) {
        receivedDraft = initialDraft;
        return Scaffold(
          body: Text(
            '${initialDraft.rating}|${initialDraft.comment}|'
            '${initialDraft.nextTimeNote}|'
            '${initialDraft.approvedPersonalVersionCreation}',
          ),
        );
      },
    );
    await tester.tap(find.text('후기 작성 이어가기'));
    await tester.pumpAndSettle();

    expect(receivedDraft, isNotNull);
    expect(receivedDraft, same(draft));
    expect(receivedDraft!.toJson(), equals(draft.toJson()));
    expect(find.text('4|양념이 조금 진했다.|간장을 반 숟갈 줄이기|true'), findsOneWidget);
  });

  testWidgets('후기 카드를 연속으로 눌러도 후기 화면은 하나만 연다', (tester) async {
    var reviewBuilds = 0;
    await _pumpMemory(
      tester,
      pendingReviewDraftLoader: () async => _buildDraft(),
      reviewScreenBuilder: (_) {
        reviewBuilds += 1;
        return const Scaffold(body: Text('단일 후기 화면'));
      },
    );

    final card = find.text('후기 작성 이어가기');
    await tester.tap(card);
    await tester.tap(card, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(reviewBuilds, 1);
    expect(find.text('단일 후기 화면'), findsOneWidget);
  });

  testWidgets('후기 화면에서 돌아오면 초안을 다시 조회한다', (tester) async {
    PendingReviewDraft? availableDraft = _buildDraft();
    var loadAttempts = 0;

    await _pumpMemory(
      tester,
      pendingReviewDraftLoader: () async {
        loadAttempts += 1;
        return availableDraft;
      },
      reviewScreenBuilder: (_) => _ReviewCloseFixture(
        beforeClose: () async {
          availableDraft = null;
        },
      ),
    );
    await tester.tap(find.text('후기 작성 이어가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('후기 저장 완료'));
    await tester.pumpAndSettle();

    expect(find.text('후기 작성 이어가기'), findsNothing);
    expect(loadAttempts, 2);
  });
}

class _EmptyReviewRepository extends ReviewRepository {
  _EmptyReviewRepository() : super(baseUrl: 'http://example.test');

  @override
  Future<List<CookingHistoryEntry>> findHistory({
    required DateTime from,
    required DateTime to,
  }) async => const [];
}

Future<void> _pumpMemory(
  WidgetTester tester, {
  required HomePendingReviewDraftLoader pendingReviewDraftLoader,
  HomeReviewScreenBuilder? reviewScreenBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCookPilotTheme(),
      home: MemoryScreen(
        reviewRepository: _EmptyReviewRepository(),
        initialDate: DateTime(2026, 8, 21),
        pendingReviewDraftLoader: pendingReviewDraftLoader,
        reviewScreenBuilder: reviewScreenBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PendingReviewDraft _buildDraft() {
  return PendingReviewDraft(
    clientSessionId: '21000000-0000-0000-0000-000000000001',
    cookedAt: DateTime.utc(2026, 7, 30, 10, 20),
    setupSnapshot: _buildSetupSnapshot(),
    timerSecondsByStep: const {0: 105},
    rating: 4,
    comment: '양념이 조금 진했다.',
    nextTimeNote: '간장을 반 숟갈 줄이기',
    approvedPersonalVersionCreation: true,
  );
}

CookingSetupSnapshot _buildSetupSnapshot() {
  return CookingSetupSnapshot(
    recipeId: '22000000-0000-0000-0000-000000000001',
    title: '두부 조림',
    description: '짭조름한 두부 반찬',
    imageUrl: '',
    baseServings: 2,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: const [
      CookingSetupIngredient(
        originalIngredientId: '23000000-0000-0000-0000-000000000001',
        originalName: '두부',
        name: '두부',
        amount: 1,
        baselineAmount: 1,
        unit: '모',
        isRequired: true,
      ),
    ],
    steps: const [
      CookingSetupStep(
        originalStepId: '24000000-0000-0000-0000-000000000001',
        stepIndex: 0,
        instruction: '두부를 노릇하게 굽는다.',
        timerSeconds: 120,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
  );
}

class _ReviewCloseFixture extends StatelessWidget {
  const _ReviewCloseFixture({required this.beforeClose});

  final Future<void> Function() beforeClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            await beforeClose();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('후기 저장 완료'),
        ),
      ),
    );
  }
}
