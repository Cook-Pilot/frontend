import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/recipe/recipe_detail_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/food_widgets.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 서버 검색 API는 아직 없다. GET /recipes 결과를 클라이언트에서 필터링한다.
/// TODO(backend): GET /recipes?q= 가 생기면 서버 검색으로 교체.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);

    return PageShell(
      title: '검색',
      children: [
        TextField(
          controller: controller,
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      setState(() => query = '');
                    },
                  ),
            hintText: '레시피 이름·설명 검색',
          ),
        ),
        AsyncValueView<List<RecipeSummary>>(
          value: recipes,
          onRetry: () => ref.invalidate(recipesProvider),
          builder: (context, list) {
            final results = query.isEmpty
                ? list
                : list
                      .where(
                        (r) =>
                            r.title.contains(query) ||
                            r.description.contains(query),
                      )
                      .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle('검색 결과 ${results.length}'),
                if (results.isEmpty)
                  const InfoStrip(
                    icon: Icons.search_off_rounded,
                    title: '결과가 없어요',
                    body: '다른 키워드로 검색해 보세요.',
                  ),
                for (final recipe in results)
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
              ],
            );
          },
        ),
      ],
    );
  }
}
