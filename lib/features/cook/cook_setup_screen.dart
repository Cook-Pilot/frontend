import 'package:cookpilot/app/app_theme.dart';
import 'package:cookpilot/core/network/api_exception.dart';
import 'package:cookpilot/data/models/cook_session.dart';
import 'package:cookpilot/data/models/personal_recipe_version.dart';
import 'package:cookpilot/data/providers.dart';
import 'package:cookpilot/data/repositories/cook_session_repository.dart';
import 'package:cookpilot/features/cook/cook_session_screen.dart';
import 'package:cookpilot/shared/widgets/async_value_view.dart';
import 'package:cookpilot/shared/widgets/page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 조리 설정 → POST /api/v1/cook-sessions 로 세션을 만든다.
class CookSetupScreen extends ConsumerStatefulWidget {
  const CookSetupScreen({
    super.key,
    required this.recipeId,
    this.initialVersionId,
  });

  final String recipeId;
  final String? initialVersionId;

  @override
  ConsumerState<CookSetupScreen> createState() => _CookSetupScreenState();
}

class _CookSetupScreenState extends ConsumerState<CookSetupScreen> {
  /// 서버 레시피에는 인분 개념이 없다. 화면에서만 배율로 쓰고, 세션 이벤트로 기록한다.
  static const baseServings = 2;

  late String? versionId = widget.initialVersionId;
  int servings = baseServings;
  bool starting = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: const Text('조리 설정'),
      ),
      body: SafeArea(
        child: AsyncValueView<RecipeDetail>(
          value: detail,
          onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
          builder: (context, data) => _buildBody(context, data),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, RecipeDetail detail) {
    final recipe = detail.recipe;
    final selected = _selectedVersion(detail.versions);
    final factor = servings / baseServings;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const SectionTitle('어떤 버전으로 조리할까요?'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    '기본',
                    selected: versionId == null,
                    onTap: () => setState(() => versionId = null),
                  ),
                  for (final version in detail.versions)
                    Pill(
                      '내 버전 v${version.versionNumber}',
                      selected: versionId == version.id,
                      onTap: () => setState(() => versionId = version.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InfoStrip(
                icon: selected == null
                    ? Icons.restaurant_menu_rounded
                    : Icons.auto_awesome_rounded,
                title: selected == null ? '기본 레시피' : selected.title,
                body: selected == null
                    ? recipe.description
                    : selected.adjustmentSummary,
              ),
              const SectionTitle('몇 인분인가요?'),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: servings > 1
                        ? () => setState(() => servings--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$servings인분',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => setState(() => servings++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '기준 $baseServings인분. 재료량은 화면에서 비례 계산하고, 인분은 세션 이벤트로 기록돼요.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SectionTitle('재료'),
              for (final item in recipe.ingredients)
                Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(item.isRequired ? '필수' : '선택'),
                    trailing: Text(
                      item.scaledAmount(factor),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              const SectionTitle('이번 조리 요약'),
              InfoStrip(
                icon: Icons.check_circle_outline_rounded,
                title:
                    '$servings인분 · ${selected == null ? '기본' : '내 버전 v${selected.versionNumber}'}',
                body:
                    '${recipe.steps.length}단계'
                    '${recipe.estimatedMinutes > 0 ? ' · 약 ${recipe.estimatedMinutes}분' : ''}',
              ),
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: starting ? null : () => _startCooking(recipe.id),
            child: starting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('이 설정으로 조리 시작'),
          ),
        ),
      ],
    );
  }

  PersonalRecipeVersion? _selectedVersion(List<PersonalRecipeVersion> versions) {
    for (final version in versions) {
      if (version.id == versionId) return version;
    }
    return null;
  }

  Future<void> _startCooking(String recipeId) async {
    setState(() => starting = true);
    final repo = ref.read(cookSessionRepositoryProvider);

    try {
      final session = await repo.create(
        recipeId,
        personalVersionId: versionId,
      );

      if (servings != baseServings) {
        await _recordServings(repo, session);
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              CookSessionScreen(session: session, servings: servings),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showApiError(context, e);
      setState(() => starting = false);
    }
  }

  /// 인분은 서버 모델에 없다. 이벤트로만 남기고, 실패해도 조리를 막지 않는다.
  Future<void> _recordServings(
    CookSessionRepository repo,
    CookSession session,
  ) async {
    try {
      await repo.addEvent(
        session.id,
        eventType: CookEventType.servingsChanged,
        stepIndex: session.currentStepIndex,
        payload: {'servings': servings},
      );
    } on ApiException {
      // 기록용 — 무시.
    }
  }
}
