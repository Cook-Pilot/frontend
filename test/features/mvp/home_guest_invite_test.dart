import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/features/mvp/main_shell.dart';
import 'package:cookpilot/features/recipe/data/recipe_api.dart';
import 'package:cookpilot/features/recipe/domain/recipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

class _GuestRecipeRepository extends RecipeRepository {
  _GuestRecipeRepository() : super(baseUrl: 'http://example.test');

  var findRecentCalls = 0;
  var findFavoritesCalls = 0;

  static const _summary = RecipeSummary(
    id: 'r-1',
    title: '라면',
    description: '데모',
    imageUrl: '',
    hasPersonalVersion: false,
    latestPersonalVersionId: null,
  );

  @override
  Future<List<RecipeSummary>> findAll() async => const [_summary];

  @override
  Future<Recipe> findById(RecipeSummary summary) async =>
      throw const RecipeApiException('상세 없음'); // featured 는 실패해도 목록은 유지된다

  @override
  Future<List<RecipeSummary>> findRecent() async {
    findRecentCalls += 1;
    return const [];
  }

  @override
  Future<List<RecipeSummary>> findFavorites() async {
    findFavoritesCalls += 1;
    return const [];
  }
}

Future<void> _pumpGuestHome(
  WidgetTester tester,
  _GuestRecipeRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCookPilotTheme(),
      home: HomeScreen(
        recipeRepository: repository,
        pendingReviewDraftLoader: () async => null,
        cookingSessionLoader: () async => null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('게스트 홈은 빈 데이터 대신 로그인 유도 카드를 보여준다', (tester) async {
    resetAuthForTest();
    final repository = _GuestRecipeRepository();

    await _pumpGuestHome(tester, repository);

    expect(find.byKey(const Key('home-recent-login-invite')), findsOneWidget);
    expect(
      find.byKey(const Key('home-favorites-login-invite')),
      findsOneWidget,
    );
    expect(find.text('아직 최근 조리 데이터가 없어요'), findsNothing);
    // 계정 데이터 요청 자체를 보내지 않는다.
    expect(repository.findRecentCalls, 0);
    expect(repository.findFavoritesCalls, 0);
  });

  testWidgets('로그인 상태면 유도 카드 대신 기존 빈 상태를 보여준다', (tester) async {
    await signInForTest();
    final repository = _GuestRecipeRepository();

    await _pumpGuestHome(tester, repository);

    expect(find.byKey(const Key('home-recent-login-invite')), findsNothing);
    expect(find.text('첫 요리를 마치고 후기를 남기면 여기에 모여요'), findsOneWidget);
    expect(repository.findRecentCalls, 1);
    expect(repository.findFavoritesCalls, 1);
  });
}
