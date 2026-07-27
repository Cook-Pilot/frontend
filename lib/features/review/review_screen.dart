import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:cookpilot/data/models/cook_session.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/data/repositories/cook_session_repository.dart';
import 'package:cookpilot/features/review/save_result_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// POST /api/v1/cook-sessions/{id}/review
/// 세션이 REVIEW 상태일 때만 저장된다. 저장 시 서버가 개인 레시피 버전을 만든다.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.session,
    required this.servings,
  });

  final CookSession session;
  final int servings;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final commentController = TextEditingController();
  final nextTimeController = TextEditingController();

  int rating = 5;
  bool saving = false;

  @override
  void dispose() {
    commentController.dispose();
    nextTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final elapsed = session.elapsed;

    return PageShell(
      title: '조리 후 리뷰',
      children: [
        Text(
          '조리 완료! 어땠나요?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => rating = i),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppColors.ink,
                  size: 34,
                ),
              ),
            const Spacer(),
            Text(
              '$rating / 5',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SectionTitle('이번 조리 요약'),
        InfoStrip(
          icon: Icons.summarize_rounded,
          title:
              '${widget.servings}인분 · ${session.isPersonalized ? '내 버전 기반' : '기본 레시피'}'
              '${elapsed == null ? '' : ' · ${elapsed.inMinutes}분 소요'}',
          body: '${session.recipeTitle} · ${session.totalSteps}단계 완료',
        ),
        const SectionTitle('한 줄 메모'),
        TextField(
          controller: commentController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '이번 조리는 어땠나요?'),
        ),
        const SectionTitle('다음엔 이렇게'),
        TextField(
          controller: nextTimeController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '예: 간장 1큰술 줄이기, 2분 더 졸이기',
          ),
        ),
        const SizedBox(height: 12),
        const InfoStrip(
          icon: Icons.info_outline_rounded,
          title: '저장하면 개인 레시피 버전이 생성돼요',
          body: '메모를 조정값으로 구조화하는 AI는 미확정이라, 서버가 목데이터 조정값으로 저장합니다.',
        ),
      ],
      bottom: FilledButton(
        onPressed: saving ? null : _submit,
        child: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('레시피 메모리에 저장'),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => saving = true);

    try {
      final review = await ref
          .read(cookSessionRepositoryProvider)
          .submitReview(
            widget.session.id,
            rating: rating,
            comment: commentController.text.trim(),
            nextTimeNote: nextTimeController.text.trim(),
          );

      // 새 개인 버전이 생겼으니 목록/메모리 캐시를 무효화한다.
      ref.invalidate(recipesProvider);
      ref.invalidate(memoriesProvider);
      ref.invalidate(recipeDetailProvider(widget.session.recipeId));

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SaveResultScreen(review: review),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() => saving = false);
    }
  }
}
