import 'dart:async';

import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending review가 없으면 기존 조리 세션을 연다', (tester) async {
    final store = _FakePendingReviewDraftStore();
    var cookingRouteBuilds = 0;
    var reviewRouteBuilds = 0;

    await _pumpSetup(
      tester,
      store: store,
      pendingReviewScreenBuilder: (_) {
        reviewRouteBuilds += 1;
        return const Scaffold(body: Text('열리면 안 되는 후기 화면'));
      },
      cookSessionScreenBuilder: (_) {
        cookingRouteBuilds += 1;
        return const Scaffold(body: Text('새 조리 화면'));
      },
    );
    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    expect(store.loadCalls, 1);
    expect(cookingRouteBuilds, 1);
    expect(reviewRouteBuilds, 0);
    expect(find.text('새 조리 화면'), findsOneWidget);
    expect(find.text('열리면 안 되는 후기 화면'), findsNothing);
  });

  testWidgets('pending review가 있으면 새 조리 대신 같은 후기를 연다', (tester) async {
    final draft = _buildDraft();
    final store = _FakePendingReviewDraftStore(draft: draft);
    PendingReviewDraft? receivedDraft;
    var cookingRouteBuilds = 0;

    await _pumpSetup(
      tester,
      store: store,
      pendingReviewScreenBuilder: (initialDraft) {
        receivedDraft = initialDraft;
        return const Scaffold(body: Text('후기 이어가기 화면'));
      },
      cookSessionScreenBuilder: (_) {
        cookingRouteBuilds += 1;
        return const Scaffold(body: Text('열리면 안 되는 조리 화면'));
      },
    );
    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    expect(store.loadCalls, 1);
    expect(receivedDraft, same(draft));
    expect(cookingRouteBuilds, 0);
    expect(find.text('후기 이어가기 화면'), findsOneWidget);
    expect(find.text('열리면 안 되는 조리 화면'), findsNothing);
    expect(find.text('작성 중인 후기를 먼저 이어갈게요.'), findsOneWidget);
  });

  testWidgets('pending review 조회 오류는 새 조리를 fail-closed한다', (tester) async {
    final store = _FakePendingReviewDraftStore(
      loadError: StateError('pending review read failure'),
    );
    var cookingRouteBuilds = 0;
    var reviewRouteBuilds = 0;

    await _pumpSetup(
      tester,
      store: store,
      pendingReviewScreenBuilder: (_) {
        reviewRouteBuilds += 1;
        return const Scaffold(body: Text('열리면 안 되는 후기 화면'));
      },
      cookSessionScreenBuilder: (_) {
        cookingRouteBuilds += 1;
        return const Scaffold(body: Text('열리면 안 되는 조리 화면'));
      },
    );
    await tester.tap(find.text('이 설정으로 조리 시작'));
    await tester.pumpAndSettle();

    expect(store.loadCalls, 1);
    expect(cookingRouteBuilds, 0);
    expect(reviewRouteBuilds, 0);
    expect(find.text('열리면 안 되는 조리 화면'), findsNothing);
    expect(find.text('열리면 안 되는 후기 화면'), findsNothing);
    expect(
      find.text('작성 중인 후기를 확인하지 못해 새 조리를 시작하지 않았어요. 다시 시도해 주세요.'),
      findsOneWidget,
    );
  });

  testWidgets('pending review 확인 중 중복 탭은 한 번만 처리한다', (tester) async {
    final pendingLoad = Completer<PendingReviewDraft?>();
    final store = _FakePendingReviewDraftStore(
      onLoad: () => pendingLoad.future,
    );
    var cookingRouteBuilds = 0;

    await _pumpSetup(
      tester,
      store: store,
      cookSessionScreenBuilder: (_) {
        cookingRouteBuilds += 1;
        return const Scaffold(body: Text('새 조리 화면'));
      },
    );
    final startButton = find.text('이 설정으로 조리 시작');
    await tester.tap(startButton);
    await tester.tap(startButton);
    await tester.pump();

    expect(store.loadCalls, 1);
    expect(find.text('작성 중 후기 확인 중'), findsOneWidget);

    pendingLoad.complete(null);
    await tester.pumpAndSettle();

    expect(store.loadCalls, 1);
    expect(cookingRouteBuilds, 1);
    expect(find.text('새 조리 화면'), findsOneWidget);
  });
}

Future<void> _pumpSetup(
  WidgetTester tester, {
  required PendingReviewDraftGateway store,
  Widget Function(PendingReviewDraft draft)? pendingReviewScreenBuilder,
  WidgetBuilder? cookSessionScreenBuilder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CookSetupScreen(
        recipe: _recipe,
        pendingReviewDraftStore: store,
        pendingReviewScreenBuilder: pendingReviewScreenBuilder,
        cookSessionScreenBuilder: cookSessionScreenBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PendingReviewDraft _buildDraft() {
  return PendingReviewDraft(
    clientSessionId: '31000000-0000-0000-0000-000000000001',
    cookedAt: DateTime.utc(2026, 7, 31, 9),
    setupSnapshot: _buildSetupSnapshot(),
    timerSecondsByStep: const {0: 60},
    rating: 4,
    comment: '작성 중인 후기',
    nextTimeNote: '다음에는 약불',
    approvedPersonalVersionCreation: true,
  );
}

CookingSetupSnapshot _buildSetupSnapshot() {
  return CookingSetupSnapshot(
    recipeId: _recipe.id,
    title: _recipe.title,
    description: _recipe.description,
    imageUrl: _recipe.imageUrl,
    baseServings: _recipe.baseServings,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: const [],
    steps: const [
      CookingSetupStep(
        originalStepId: '33000000-0000-0000-0000-000000000001',
        stepIndex: 0,
        instruction: '두부를 굽는다.',
        timerSeconds: 60,
        cautionNote: null,
        imageUrl: '',
      ),
    ],
  );
}

const _recipe = Recipe(
  id: '32000000-0000-0000-0000-000000000001',
  title: '두부 구이',
  description: '조리 진입 guard 테스트',
  baseServings: 2,
  imageUrl: '',
  ingredients: [],
  steps: [
    CookStep(
      originalStepId: '33000000-0000-0000-0000-000000000001',
      stepIndex: 0,
      instruction: '두부를 굽는다.',
      timerSeconds: 60,
      cautionNote: null,
      imageUrl: '',
    ),
  ],
  hasPersonalVersion: false,
);

final class _FakePendingReviewDraftStore implements PendingReviewDraftGateway {
  _FakePendingReviewDraftStore({this.draft, this.loadError, this.onLoad});

  PendingReviewDraft? draft;
  final Object? loadError;
  final Future<PendingReviewDraft?> Function()? onLoad;
  var loadCalls = 0;

  @override
  Future<void> save(PendingReviewDraft draft) async {
    this.draft = draft;
  }

  @override
  Future<PendingReviewDraft?> load() async {
    loadCalls += 1;
    final loader = onLoad;
    if (loader != null) {
      return loader();
    }
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return draft;
  }

  @override
  Future<void> clear() async {
    draft = null;
  }
}
