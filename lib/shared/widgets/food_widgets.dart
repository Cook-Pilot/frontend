import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/models/recipe.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';

/// 이미지 파이프라인이 아직 없다. 자리를 잡아두는 플레이스홀더.
class FoodPreview extends StatelessWidget {
  const FoodPreview({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size.isFinite ? size : double.infinity;
    final height = size.isFinite ? size : 138.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        color: AppColors.slate,
        size: height * 0.34,
      ),
    );
  }
}

class FoodTile extends StatelessWidget {
  const FoodTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const FoodPreview(size: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 상단 카드. 내 버전 유무를 배지로 보여준다 (GET /recipes 응답 필드).
class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({super.key, required this.recipe, this.onTap});

  final RecipeSummary recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FoodPreview(size: double.infinity),
              const SizedBox(height: 14),
              Text(
                recipe.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                recipe.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 12),
              Pill(
                recipe.hasPersonalVersion ? '나 맞춤 버전 있음' : '기본 레시피',
                selected: recipe.hasPersonalVersion,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
