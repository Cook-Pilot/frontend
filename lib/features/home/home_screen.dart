import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/recipe/recipe_detail_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/food_widgets.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GET /api/v1/recipes
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider);
    final user = ref.watch(currentUserProvider);

    return PageShell(
      title: 'CookPilot',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(recipesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        user.when(
          data: (data) => InfoStrip(
            icon: Icons.person_rounded,
            title: '${data.displayName} 님',
            body: '인증 미확정 · 서버 고정 계정(${data.email})으로 동작합니다.',
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        AsyncValueView<List<RecipeSummary>>(
          value: recipes,
          onRetry: () => ref.invalidate(recipesProvider),
          builder: (context, list) => _HomeBody(recipes: list),
        ),
      ],
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.recipes});

  final List<RecipeSummary> recipes;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const InfoStrip(
        icon: Icons.no_meals_rounded,
        title: '레시피가 없어요',
        body: '백엔드 시드 레시피(라면, 김치볶음밥)가 로드되지 않았습니다.',
      );
    }

    final personalized = recipes.where((r) => r.hasPersonalVersion).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('오늘의 메뉴'),
        RecipeHeroCard(
          recipe: recipes.first,
          onTap: () => openRecipeDetail(context, recipes.first.id),
        ),
        const SectionTitle('전체 레시피'),
        for (final recipe in recipes)
          FoodTile(
            title: recipe.title,
            subtitle: recipe.description,
            trailing: Icon(
              recipe.hasPersonalVersion
                  ? Icons.auto_awesome_rounded
                  : Icons.chevron_right_rounded,
              color: recipe.hasPersonalVersion
                  ? AppColors.ink
                  : AppColors.muted,
            ),
            onTap: () => openRecipeDetail(context, recipe.id),
          ),
        const SectionTitle('나 맞춤 버전'),
        if (personalized.isEmpty)
          const InfoStrip(
            icon: Icons.history_rounded,
            title: '아직 내 버전이 없어요',
            body: '조리를 마치고 리뷰를 남기면 개인 레시피 버전이 자동 생성돼요.',
          )
        else
          for (final recipe in personalized)
            FoodTile(
              title: recipe.title,
              subtitle: '나 맞춤 버전 있음',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openRecipeDetail(context, recipe.id),
            ),
      ],
    );
  }
}
