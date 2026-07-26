import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/review/data/review_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const recipeId = '10000000-0000-0000-0000-000000000001';

  CookingHistoryEntry history({
    required String reviewId,
    required DateTime cookedAt,
    required int rating,
    required String comment,
    required String nextTimeNote,
    int? versionNumber,
  }) {
    return CookingHistoryEntry(
      reviewId: reviewId,
      recipeId: recipeId,
      recipeTitle: '계란볶음밥',
      recipeImageUrl: '',
      cookedAt: cookedAt,
      rating: rating,
      comment: comment,
      nextTimeNote: nextTimeNote,
      sourcePersonalVersionId: null,
      createdPersonalVersionId: versionNumber == null
          ? null
          : '20000000-0000-0000-0000-00000000000$versionNumber',
      createdPersonalVersionNumber: versionNumber,
      createdPersonalVersionSummary: versionNumber == null ? null : '간장 양 조정',
    );
  }

  testWidgets('달력의 조리 카드를 누르면 바텀시트 대신 상세 화면으로 이동한다', (tester) async {
    final repository = _FakeReviewRepository([
      history(
        reviewId: '50000000-0000-0000-0000-000000000001',
        cookedAt: DateTime(2026, 7, 26, 12),
        rating: 5,
        comment: '간을 줄이니 딱 좋았다.',
        nextTimeNote: '대파를 조금 더 넣어보기',
        versionNumber: 1,
      ),
      history(
        reviewId: '50000000-0000-0000-0000-000000000002',
        cookedAt: DateTime(2026, 7, 12, 12),
        rating: 4,
        comment: '조금 짰다.',
        nextTimeNote: '',
      ),
      history(
        reviewId: '50000000-0000-0000-0000-000000000003',
        cookedAt: DateTime(2026, 7, 30, 12),
        rating: 3,
        comment: '선택한 기록보다 나중 조리했다.',
        nextTimeNote: '',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCookPilotTheme(),
        home: MemoryScreen(
          reviewRepository: repository,
          initialDate: DateTime(2026, 7, 26),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dish = find.text('계란볶음밥');
    expect(dish, findsOneWidget);
    await tester.ensureVisible(dish);
    await tester.pumpAndSettle();
    await tester.tap(dish);
    await tester.pumpAndSettle();

    expect(find.byType(CookingHistoryDetailScreen), findsOneWidget);
    expect(find.text('조리 기록'), findsOneWidget);
    expect(find.text('2026년 7월 26일'), findsOneWidget);
    expect(find.text('★★★★★  5.0'), findsOneWidget);
    expect(find.text('개인 레시피 v1 생성'), findsOneWidget);
    expect(find.text('간을 줄이니 딱 좋았다.'), findsOneWidget);
    expect(find.text('대파를 조금 더 넣어보기'), findsOneWidget);
    expect(find.text('같은 요리의 다른 기록'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2026년 7월 30일'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('2026년 7월 30일'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2026년 7월 12일'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('2026년 7월 12일'), findsOneWidget);
  });
}

class _FakeReviewRepository extends ReviewRepository {
  _FakeReviewRepository(this.entries) : super(baseUrl: 'http://example.test');

  final List<CookingHistoryEntry> entries;

  @override
  Future<List<CookingHistoryEntry>> findHistory({
    required DateTime from,
    required DateTime to,
  }) async {
    return entries;
  }
}
