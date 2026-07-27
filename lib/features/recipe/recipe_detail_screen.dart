import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/cook/cook_setup_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/food_widgets.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GET /recipes/{id} + GET /recipes/{id}/personal-versions
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(recipeDetailProvider(recipeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: const Text('레시피 상세'),
      ),
      body: SafeArea(
        child: AsyncValueView<RecipeDetail>(
          value: detail,
          onRetry: () => ref.invalidate(recipeDetailProvider(recipeId)),
          builder: (context, data) => _DetailBody(detail: data),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final RecipeDetail detail;

  @override
  Widget build(BuildContext context) {
    final recipe = detail.recipe;
    final latest = detail.latestVersion;
    final canCook = recipe.steps.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const FoodPreview(size: double.infinity),
              const SizedBox(height: 18),
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                recipe.description,
                style: const TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 6),
              Text(
                '${recipe.steps.length}단계'
                '${recipe.estimatedMinutes > 0 ? ' · 약 ${recipe.estimatedMinutes}분' : ''}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SectionTitle('필요한 재료'),
              for (final item in recipe.ingredients)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.isRequired
                        ? Icons.check_circle_outline_rounded
                        : Icons.add_circle_outline_rounded,
                    color: item.isRequired ? AppColors.ink : AppColors.muted,
                  ),
                  title: Text('${item.name} ${item.displayAmount}'),
                  subtitle: Text(item.isRequired ? '필수' : '선택'),
                ),
              const SectionTitle('내 기록'),
              if (latest == null)
                const InfoStrip(
                  icon: Icons.history_rounded,
                  title: '아직 내 버전이 없어요',
                  body: '조리를 마치고 리뷰를 남기면 나 맞춤 버전이 자동으로 생성돼요.',
                )
              else
                InfoStrip(
                  icon: Icons.auto_awesome_rounded,
                  title:
                      '내 버전 ${detail.versions.length}개 · 최신 v${latest.versionNumber}',
                  body: latest.adjustmentSummary,
                ),
              const SectionTitle('조리 순서'),
              for (final step in recipe.steps)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    child: Text('${step.stepIndex + 1}'),
                  ),
                  title: Text(step.instruction),
                  subtitle: Text(
                    [
                      if (step.hasTimer) '타이머 ${step.timerLabel}',
                      if (step.cautionNote != null) '⚠ ${step.cautionNote}',
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: canCook
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CookSetupScreen(recipeId: recipe.id),
                    ),
                  )
                : null,
            child: Text(canCook ? '조리 설정하기' : '조리 단계 없음'),
          ),
        ),
      ],
    );
  }
}

Future<void> openRecipeDetail(BuildContext context, String recipeId) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RecipeDetailScreen(recipeId: recipeId),
    ),
  );
}
