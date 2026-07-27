import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/models/personal_recipe_version.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/cook/cook_setup_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// GET /api/v1/recipes/{id}/personal-versions — 레시피별 내 버전.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoriesProvider);

    return PageShell(
      title: '레시피 메모리',
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(memoriesProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        AsyncValueView<List<RecipeMemory>>(
          value: memories,
          onRetry: () => ref.invalidate(memoriesProvider),
          builder: (context, list) {
            if (list.isEmpty) {
              return const InfoStrip(
                icon: Icons.inventory_2_outlined,
                title: '저장된 버전이 없어요',
                body: '조리를 마치고 리뷰를 남기면 개인 레시피 버전이 자동 생성됩니다.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final memory in list) ...[
                  SectionTitle(
                    '${memory.recipe.title} · 버전 ${memory.versions.length}개',
                  ),
                  for (final version in memory.versions)
                    _VersionCard(
                      recipe: memory.recipe,
                      version: version,
                      onCook: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CookSetupScreen(
                              recipeId: memory.recipe.id,
                              initialVersionId: version.id,
                            ),
                          ),
                        );
                        ref.invalidate(memoriesProvider);
                      },
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.recipe,
    required this.version,
    required this.onCook,
  });

  final RecipeSummary recipe;
  final PersonalRecipeVersion version;
  final VoidCallback onCook;

  @override
  Widget build(BuildContext context) {
    final isLatest = recipe.latestPersonalVersionId == version.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    version.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isLatest) const Pill('최신', selected: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              version.adjustmentSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            Text(
              'v${version.versionNumber} · ${formatDateTime(version.createdAt)}'
              '${version.isMockAdjustment ? ' · 조정값 목데이터' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onCook,
                child: const Text('이 버전으로 조리'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatDateTime(DateTime? time) {
  if (time == null) return '날짜 미상';
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.month}월 ${local.day}일 ${two(local.hour)}:${two(local.minute)}';
}
