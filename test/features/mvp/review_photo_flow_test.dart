import 'dart:async';

import 'package:cookpilot/features/cooking/domain/cooking_setup_snapshot.dart';
import 'package:cookpilot/features/mvp/cook_flow_screens.dart';
import 'package:cookpilot/features/review/application/pending_review_draft_store.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
import 'package:cookpilot/features/review/presentation/review_photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/review_photo_fakes.dart';
import '../../helpers/auth_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 후기 저장이 로그인 게이트를 지나야 하므로 로그인 상태로 돌린다.
    await signInForTest();
  });

  // 전역 세션 상태가 다른 테스트로 새지 않게 되돌린다.
  tearDown(resetAuthForTest);

  testWidgets('사진을 첨부하면 즉시 업로드를 시작하고 draft에 보존하며 삭제할 수 있다', (tester) async {
    final picker = FakeReviewPhotoPicker()
      ..queuedResults.add('/cache/picked-1.jpg');
    final files = InMemoryReviewPhotoFileStore();
    final uploader = FakeReviewPhotoUploadPort();
    final store = _InMemoryDraftStore();

    await _pumpReview(
      tester,
      picker: picker,
      files: files,
      uploader: uploader,
      store: store,
    );

    await _addPhotoFromCamera(tester);

    expect(picker.requestedSources, [ReviewPhotoSource.camera]);
    expect(files.importCount, 1);
    // 첨부 즉시(저장 버튼 전) 업로드가 시작·완료됐다.
    expect(uploader.uploadedPaths, hasLength(1));
    expect(find.byKey(const Key('review-photo-0')), findsOneWidget);
    expect(store.savedDrafts.last.photoPaths, hasLength(1));

    await tester.tap(find.byKey(const Key('review-photo-remove-0')));
    await _pumpAsyncWork(tester);

    expect(find.byKey(const Key('review-photo-0')), findsNothing);
    expect(files.deletedPaths, hasLength(1));
    expect(store.savedDrafts.last.photoPaths, isEmpty);
  });

  testWidgets('10장 상한에 도달하면 추가 버튼을 숨긴다', (tester) async {
    final files = InMemoryReviewPhotoFileStore();
    final paths = <String>[];
    for (var i = 0; i < PendingReviewDraft.maximumPhotoCount; i += 1) {
      paths.add(
        await files.importPhoto(
          clientSessionId: _sessionId,
          sourcePath: '/cache/$i.jpg',
        ),
      );
    }

    await _pumpReview(
      tester,
      files: files,
      initialDraft: _draft(photoPaths: paths),
    );
    await _pumpAsyncWork(tester);

    expect(find.byKey(const Key('review-photo-add-button')), findsNothing);
    expect(find.byKey(const Key('review-photo-9')), findsOneWidget);
  });

  testWidgets('업로드 실패 장이 있으면 제출을 중단하고, 재시도 후 순서대로 photoUrls를 보낸다', (
    tester,
  ) async {
    final files = InMemoryReviewPhotoFileStore();
    final first = await files.importPhoto(
      clientSessionId: _sessionId,
      sourcePath: '/cache/1.jpg',
    );
    final second = await files.importPhoto(
      clientSessionId: _sessionId,
      sourcePath: '/cache/2.jpg',
    );
    final uploader = FakeReviewPhotoUploadPort()
      ..failingPaths.add('/documents/$second');
    final repository = _FakeReviewRepository();
    final store = _InMemoryDraftStore();

    await _pumpReview(
      tester,
      files: files,
      uploader: uploader,
      reviewRepository: repository,
      store: store,
      initialDraft: _draft(photoPaths: [first, second]),
    );
    await _pumpAsyncWork(tester);

    // 선업로드에서 두 번째 장이 실패해 배지가 떠 있다.
    expect(find.byKey(const Key('review-photo-retry-1')), findsOneWidget);

    await tester.tap(find.text('조리 기록 저장'));
    await _pumpAsyncWork(tester);

    // 실패 장이 있으면 리뷰 POST를 보내지 않는다(사진 없는 저장은 영구 미첨부).
    expect(repository.calls, 0);
    expect(find.textContaining('사진을 업로드하지 못했습니다'), findsOneWidget);
    // 성공한 첫 장은 저장 시도에서 재업로드하지 않았다(캐시 재사용).
    expect(
      uploader.uploadedPaths.where((path) => path == '/documents/$first'),
      hasLength(1),
    );

    uploader.failingPaths.clear();
    await tester.tap(find.byKey(const Key('review-photo-retry-1')));
    await _pumpAsyncWork(tester);
    await tester.tap(find.text('조리 기록 저장'));
    await _pumpAsyncWork(tester);

    expect(repository.calls, 1);
    expect(repository.submittedPhotoUrls.single, [
      'https://cdn.example.test/imported-1.jpg',
      'https://cdn.example.test/imported-2.jpg',
    ]);
    // 저장 성공 후 세션 사진 디렉토리를 정리했다.
    expect(files.clearedSessions, [_sessionId]);
    expect(find.text('테스트 홈 화면'), findsOneWidget);
  });

  testWidgets('저장은 진행 중인 업로드를 기다렸다가 완료 후 제출한다', (tester) async {
    final files = InMemoryReviewPhotoFileStore();
    final path = await files.importPhoto(
      clientSessionId: _sessionId,
      sourcePath: '/cache/1.jpg',
    );
    final gate = Completer<void>();
    final uploader = FakeReviewPhotoUploadPort()..gate = gate;
    final repository = _FakeReviewRepository();

    await _pumpReview(
      tester,
      files: files,
      uploader: uploader,
      reviewRepository: repository,
      initialDraft: _draft(photoPaths: [path]),
    );
    await tester.pump();

    await tester.tap(find.text('조리 기록 저장'));
    await tester.pump();

    // 업로드가 끝나기 전에는 제출하지 않는다.
    expect(repository.calls, 0);

    gate.complete();
    await _pumpAsyncWork(tester);

    expect(repository.calls, 1);
    expect(repository.submittedPhotoUrls.single, hasLength(1));
  });

  testWidgets('서버가 이미 수락한 후기(acceptedReviewId)는 업로드를 시작하지 않는다', (tester) async {
    final files = InMemoryReviewPhotoFileStore();
    final path = await files.importPhoto(
      clientSessionId: _sessionId,
      sourcePath: '/cache/1.jpg',
    );
    final uploader = FakeReviewPhotoUploadPort();
    final repository = _FakeReviewRepository();

    await _pumpReview(
      tester,
      files: files,
      uploader: uploader,
      reviewRepository: repository,
      initialDraft: _draft(
        photoPaths: [path],
        acceptedReviewId: '50000000-0000-0000-0000-000000000001',
      ),
    );
    await _pumpAsyncWork(tester);

    // 멱등 재전송은 photoUrls를 무시하므로 업로드 자체가 무의미하다.
    expect(uploader.uploadedPaths, isEmpty);
    // 잠금 상태라 추가 버튼도 비활성 경로다(삭제 배지 미표시).
    expect(find.byKey(const Key('review-photo-remove-0')), findsNothing);

    await tester.tap(find.text('조리 기록 저장'));
    await _pumpAsyncWork(tester);

    expect(uploader.uploadedPaths, isEmpty);
    expect(repository.calls, 0);
    expect(find.text('테스트 홈 화면'), findsOneWidget);
  });

  testWidgets('기기에서 사라진 사진은 복원 시 제외하고 안내한다', (tester) async {
    final files = InMemoryReviewPhotoFileStore();
    final kept = await files.importPhoto(
      clientSessionId: _sessionId,
      sourcePath: '/cache/1.jpg',
    );
    const missing = 'review_photos/$_sessionId/gone.jpg';
    final store = _InMemoryDraftStore();

    await _pumpReview(
      tester,
      files: files,
      store: store,
      initialDraft: _draft(photoPaths: [kept, missing]),
    );
    await _pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('review-photo-missing-notice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('review-photo-0')), findsOneWidget);
    expect(find.byKey(const Key('review-photo-1')), findsNothing);
    expect(store.savedDrafts.last.photoPaths, [kept]);
  });
}

const _sessionId = '40000000-0000-0000-0000-000000000002';

CookingSetupSnapshot _snapshot() {
  return CookingSetupSnapshot(
    recipeId: '10000000-0000-0000-0000-000000000092',
    title: '후기 사진 테스트',
    description: '사진 첨부와 업로드 순서를 검증한다.',
    imageUrl: '',
    baseServings: 2,
    targetServings: 2,
    source: CookingRecipeSource.base,
    personalVersionId: null,
    ingredients: const <CookingSetupIngredient>[],
    steps: const <CookingSetupStep>[
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
  List<String> photoPaths = const [],
  String? acceptedReviewId,
}) {
  return PendingReviewDraft(
    clientSessionId: _sessionId,
    cookedAt: DateTime.utc(2026, 7, 30, 9),
    setupSnapshot: _snapshot(),
    timerSecondsByStep: const <int, int>{},
    rating: 5,
    comment: '',
    nextTimeNote: '',
    approvedPersonalVersionCreation: false,
    acceptedReviewId: acceptedReviewId,
    photoPaths: photoPaths,
  );
}

Future<void> _pumpReview(
  WidgetTester tester, {
  FakeReviewPhotoPicker? picker,
  InMemoryReviewPhotoFileStore? files,
  FakeReviewPhotoUploadPort? uploader,
  _FakeReviewRepository? reviewRepository,
  _InMemoryDraftStore? store,
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
        pendingReviewDraftStore: store ?? _InMemoryDraftStore(),
        reviewRepository: reviewRepository ?? _FakeReviewRepository(),
        reviewPhotoPicker: picker ?? FakeReviewPhotoPicker(),
        reviewPhotoFileStore: files ?? InMemoryReviewPhotoFileStore(),
        reviewPhotoUploader: uploader ?? FakeReviewPhotoUploadPort(),
        homeBuilder: (_) => const _TestHome(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _addPhotoFromCamera(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('review-photo-add-button')));
  await tester.tap(find.byKey(const Key('review-photo-add-button')));
  await _pumpAsyncWork(tester);
  await tester.tap(find.byKey(const Key('review-photo-source-camera')));
  await _pumpAsyncWork(tester);
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  for (var i = 0; i < 5; i += 1) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _TestHome extends StatelessWidget {
  const _TestHome();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('테스트 홈 화면'));
}

final class _InMemoryDraftStore implements PendingReviewDraftGateway {
  final List<PendingReviewDraft> savedDrafts = [];
  PendingReviewDraft? _stored;

  @override
  Future<void> save(PendingReviewDraft draft) async {
    savedDrafts.add(draft);
    _stored = draft;
  }

  @override
  Future<PendingReviewDraft?> load() async => _stored;

  @override
  Future<void> clear() async {
    _stored = null;
  }
}

final class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository() : super(baseUrl: 'http://example.test');

  int calls = 0;
  final List<List<String>> submittedPhotoUrls = <List<String>>[];

  @override
  Future<ReviewSaveResult> submit({
    required String clientSessionId,
    required DateTime cookedAt,
    required CookingSetupSnapshot snapshot,
    required int rating,
    required String comment,
    required String nextTimeNote,
    List<String> photoUrls = const [],
  }) async {
    calls += 1;
    submittedPhotoUrls.add(photoUrls);
    return const ReviewSaveResult(
      id: '50000000-0000-0000-0000-000000000001',
      createdPersonalVersionId: null,
    );
  }
}
