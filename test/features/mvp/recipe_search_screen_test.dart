import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('요리 이름과 재료를 서버에 보내고 5페이지씩 이동한다', (tester) async {
    final repository = _FakeRecipeRepository();

    await tester.pumpWidget(
      MaterialApp(home: SearchScreen(recipeRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(repository.calls.single, const _SearchCall(page: 1));

    await tester.enterText(find.byType(TextField).at(0), '가지 탕수육');
    await tester.enterText(find.byType(TextField).at(1), '가지');
    await tester.tap(find.widgetWithText(FilledButton, '검색'));
    await tester.pumpAndSettle();

    expect(
      repository.calls.last,
      const _SearchCall(title: '가지 탕수육', ingredient: '가지', page: 1),
    );
    expect(find.text('검색 결과 103'), findsOneWidget);
    expect(find.text('1 / 12'), findsOneWidget);
    final nextFiveSize = tester.getSize(find.byTooltip('5페이지 다음'));
    expect(nextFiveSize.width, greaterThanOrEqualTo(48));
    expect(nextFiveSize.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('5페이지 다음'));
    await tester.pumpAndSettle();

    expect(
      repository.calls.last,
      const _SearchCall(title: '가지 탕수육', ingredient: '가지', page: 6),
    );
    expect(find.text('6 / 12'), findsOneWidget);

    await tester.tap(find.byTooltip('마지막 페이지'));
    await tester.pumpAndSettle();
    expect(repository.calls.last.page, 12);

    await tester.tap(find.byTooltip('처음 페이지'));
    await tester.pumpAndSettle();
    expect(repository.calls.last.page, 1);
  });

  testWidgets('초기화는 검색 조건과 페이지를 함께 되돌린다', (tester) async {
    final repository = _FakeRecipeRepository();

    await tester.pumpWidget(
      MaterialApp(home: SearchScreen(recipeRepository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '김치찌개');
    await tester.enterText(find.byType(TextField).at(1), '두부');
    await tester.tap(find.widgetWithText(FilledButton, '검색'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5페이지 다음'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '초기화'));
    await tester.pumpAndSettle();

    expect(repository.calls.last, const _SearchCall(page: 1));
    expect(find.byType(TextField).at(0), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      isEmpty,
    );
  });
}

class _FakeRecipeRepository extends RecipeRepository {
  _FakeRecipeRepository() : super(baseUrl: 'http://example.test');

  final calls = <_SearchCall>[];

  @override
  Future<RecipeSearchPage> search({
    String title = '',
    String ingredient = '',
    int page = 1,
    int size = 9,
  }) async {
    calls.add(
      _SearchCall(title: title, ingredient: ingredient, page: page, size: size),
    );
    return RecipeSearchPage(
      items: [
        RecipeSummary(
          id: '10000000-0000-0000-0000-${page.toString().padLeft(12, '0')}',
          title: title.isEmpty ? '전체 레시피 $page' : '$title $page',
          description: ingredient.isEmpty ? '기본 검색 결과' : '$ingredient 포함',
          imageUrl: '',
          hasPersonalVersion: false,
          latestPersonalVersionId: null,
        ),
      ],
      page: page,
      pageSize: size,
      totalPages: 12,
      totalItems: 103,
    );
  }
}

class _SearchCall {
  const _SearchCall({
    this.title = '',
    this.ingredient = '',
    this.page = 1,
    this.size = 9,
  });

  final String title;
  final String ingredient;
  final int page;
  final int size;

  @override
  bool operator ==(Object other) {
    return other is _SearchCall &&
        other.title == title &&
        other.ingredient == ingredient &&
        other.page == page &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(title, ingredient, page, size);
}
