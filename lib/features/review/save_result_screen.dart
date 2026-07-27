import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/data/models/personal_recipe_version.dart';
import 'package:cookpilot/data/models/review.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/features/shell/main_shell.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 저장 결과. GET /api/v1/personal-versions/{id} 로 서버가 만든 버전을 보여준다.
class SaveResultScreen extends ConsumerWidget {
  const SaveResultScreen({super.key, required this.review});

  final PostCookReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionId = review.createdPersonalVersionId;

    return PageShell(
      title: '저장 완료',
      children: [
        const InfoStrip(
          icon: Icons.check_circle_rounded,
          title: '리뷰가 저장됐어요',
          body: '세션은 COMPLETED로 전환되고, 개인 레시피 버전이 자동 생성됩니다.',
        ),
        const SectionTitle('생성된 내 버전'),
        if (versionId == null)
          const InfoStrip(
            icon: Icons.help_outline_rounded,
            title: '생성된 버전이 없어요',
            body: '서버가 개인 버전 ID를 반환하지 않았습니다.',
          )
        else
          AsyncValueView<PersonalRecipeVersion>(
            value: ref.watch(personalVersionProvider(versionId)),
            onRetry: () => ref.invalidate(personalVersionProvider(versionId)),
            loadingHeight: 120,
            builder: (context, version) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      version.adjustmentSummary,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill('v${version.versionNumber}', selected: true),
                        Pill('★ ${review.rating}'),
                        if (version.isMockAdjustment) const Pill('조정값 목데이터'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SectionTitle('저장된 정보'),
        const Text(
          '만족도 · 코멘트 · 다음엔 이렇게 메모 · 조리 세션 이벤트 기록',
          style: TextStyle(color: AppColors.slate),
        ),
      ],
      bottom: FilledButton(
        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
          (route) => false,
        ),
        child: const Text('홈으로'),
      ),
    );
  }
}
