import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../cooking/application/cooking_ports.dart';
import '../cooking/application/cooking_session_controller.dart';
import '../cooking/application/cooking_session_store.dart';
import '../cooking/application/timer_controller.dart';
import '../cooking/domain/cooking_session_state.dart';
import '../cooking/presentation/cooking_screen.dart';
import '../cooking/presentation/timer_alarm_provider.dart';
import 'main_shell.dart';
import 'mock_data.dart';
import 'mvp_widgets.dart';
import 'recipe_cooking_steps.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final canCook = recipe.steps.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: const _CircleAction(icon: Icons.chevron_left_rounded),
            actions: const [
              _CircleAction(icon: Icons.bookmark_outline_rounded),
              SizedBox(width: 6),
              _CircleAction(icon: Icons.ios_share_rounded),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(image: recipe.image, radius: 0),
                  // 상단 시스템 아이콘, 하단 본문 경계 가독성용 그라데이션.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.25, 0.8, 1],
                        colors: [
                          Color(0x66201005),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x33201005),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      if (recipe.badge != null) ImageLabelChip(recipe.badge!),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.subtitle,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                  const SizedBox(height: 8),
                  RatingBadge(recipe.rating, reviewCount: recipe.reviewCount),
                  const SizedBox(height: 18),
                  // 핵심 스탯 타일 3개
                  Row(
                    children: [
                      _StatTile(
                        icon: Icons.schedule_rounded,
                        label: '조리 시간',
                        value: '${recipe.minutes}분',
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        icon: Icons.local_fire_department_rounded,
                        label: '난이도',
                        value: recipe.difficulty,
                      ),
                      const SizedBox(width: 10),
                      const _StatTile(
                        icon: Icons.people_alt_rounded,
                        label: '기준',
                        value: '2인분',
                      ),
                    ],
                  ),
                  const SectionTitle('필요한 재료'),
                  if (recipe.ingredients.isEmpty)
                    const InfoStrip(
                      icon: Icons.info_outline_rounded,
                      title: '상세 재료 준비 중',
                      body: '현재 MVP에서는 두부 조림 레시피를 중심으로 조리 흐름을 확인할 수 있어요.',
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppShape.inner),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          for (final (i, item) in recipe.ingredients.indexed)
                            _IngredientRow(
                              item: item,
                              showDivider: i < recipe.ingredients.length - 1,
                            ),
                        ],
                      ),
                    ),
                  const SectionTitle('내 기록'),
                  InfoStrip(
                    icon: Icons.history_rounded,
                    title: '나 맞춤 버전 있음',
                    body: recipe.memorySummary,
                  ),
                  const SectionTitle('조리 순서'),
                  if (recipe.steps.isEmpty)
                    const InfoStrip(
                      icon: Icons.construction_rounded,
                      title: '조리 단계 준비 중',
                      body: '전체 조리 플로우는 두부 조림에서 먼저 검증합니다.',
                    )
                  else
                    for (var i = 0; i < recipe.steps.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accentSoft,
                          foregroundColor: AppColors.accent,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          recipe.steps[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('약 ${recipe.steps[i].minutes}분'),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: PressableScale(
          child: FilledButton(
            onPressed: canCook
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CookSetupScreen(recipe: recipe),
                      ),
                    );
                  }
                : null,
            child: Text(canCook ? '조리 설정하기' : '조리 단계 준비 중'),
          ),
        ),
      ),
    );
  }
}

/// SliverAppBar 위에 얹는 반투명 원형 아이콘 버튼.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isBack = icon == Icons.chevron_left_rounded;
    return Center(
      child: PressableScale(
        child: GestureDetector(
          onTap: isBack && canPop ? () => Navigator.of(context).pop() : () {},
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xD9FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.ink, size: 22),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.wash,
          borderRadius: BorderRadius.circular(AppShape.inner),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item, required this.showDivider});

  final Ingredient item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.note,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                item.amount,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class CookSetupScreen extends StatefulWidget {
  const CookSetupScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookSetupScreen> createState() => _CookSetupScreenState();
}

class _CookSetupScreenState extends State<CookSetupScreen> {
  int servings = 2;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '조리 설정',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
      children: [
        const Wrap(
          spacing: 8,
          children: [Pill('기본'), Pill('나 맞춤', selected: true), Pill('남의 추천')],
        ),
        const SizedBox(height: 12),
        InfoStrip(
          icon: Icons.auto_awesome_rounded,
          title: '나 맞춤 버전',
          body: widget.recipe.memorySummary,
        ),
        const SectionTitle('몇 인분인가요?'),
        Row(
          children: [
            PressableScale(
              child: IconButton.filledTonal(
                onPressed: servings > 1
                    ? () => setState(() => servings--)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$servings인분',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            PressableScale(
              child: IconButton.filled(
                onPressed: () => setState(() => servings++),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        const SectionTitle('재료 변경'),
        for (final ingredient in widget.recipe.ingredients)
          Card(
            child: ListTile(
              title: Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                ingredient.amount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => _openIngredientSheet(context, ingredient),
                child: const Text('수정'),
              ),
            ),
          ),
        const SectionTitle('이번 조리 요약'),
        InfoStrip(
          icon: Icons.check_circle_outline_rounded,
          title: '$servings인분 · 나 맞춤',
          body: '설탕 생략 · 간장 15% 감소 · 중불 유지',
        ),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CookSessionScreen(
                  recipe: widget.recipe,
                  servings: servings,
                ),
              ),
            );
          },
          child: const Text('이 설정으로 조리 시작'),
        ),
      ),
    );
  }

  void _openIngredientSheet(BuildContext context, Ingredient ingredient) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ingredient.name} · ${ingredient.amount}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                children: [
                  Pill('양 조절', selected: true),
                  Pill('대체'),
                  Pill('생략'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Text(
                      ingredient.amount,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const InfoStrip(
                icon: Icons.calculate_rounded,
                title: '비율 자동 재계산',
                body: '간장을 줄이면 나머지 양념 비율이 함께 조정돼요.',
              ),
              const SizedBox(height: 18),
              PressableScale(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('적용'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 실제 조리 세션 화면의 호스트.
///
/// [CookingSessionController]와 [CookingScreen]을 MVP 플로우에 연결하고,
/// 진행 상태(현재 단계·타이머)를 [CookingSessionStore]에 저장해 앱을 껐다
/// 켜도 이어서 조리할 수 있게 한다.
class CookSessionScreen extends StatefulWidget {
  const CookSessionScreen({
    super.key,
    required this.recipe,
    required this.servings,
    this.restoredSession,
  });

  final Recipe recipe;
  final int servings;

  /// 홈의 "이어서 조리하기"로 진입할 때 전달되는 저장 세션.
  final PersistedCookingSession? restoredSession;

  @override
  State<CookSessionScreen> createState() => _CookSessionScreenState();
}

class _CookSessionScreenState extends State<CookSessionScreen> {
  final CookingSessionStore _store = const CookingSessionStore();

  CookingSessionController? _controller;

  // 타이머가 250ms마다 알림을 보내므로, 마지막으로 저장한 상태를 기억해
  // 의미 있는 변화(단계·상태·연장)가 있을 때만 저장한다. 남은 시간은 저장
  // 시각과 함께 기록해 복원 시 재계산하므로 매 틱 저장이 필요 없다.
  int? _persistedStepIndex;
  CookingSessionStatus? _persistedSessionStatus;
  TimerStatus? _persistedTimerStatus;
  Duration? _persistedTimerEffective;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareSession());
  }

  Future<void> _prepareSession() async {
    final alarm = await resolveTimerAlarm();
    if (!mounted) {
      return;
    }
    final restored = widget.restoredSession;
    final controller = CookingSessionController(
      recipeId: widget.recipe.title,
      recipeVersionId: 'my-custom',
      steps: cookingStepsFromRecipe(widget.recipe),
      timer: LocalTimerController(),
      speechInput: DemoSpeechInput(),
      speechOutput: DemoSpeechOutput(),
      exceptionAdvice: DemoExceptionAdvicePort(),
      alarm: alarm,
      initialStepIndex: restored?.stepIndex ?? 0,
      initialTimerSnapshot: restored?.timerSnapshotAt(DateTime.now()),
    );
    controller.addListener(_persistSession);
    setState(() => _controller = controller);
    _persistSession();
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_persistSession)
      ..dispose();
    super.dispose();
  }

  void _persistSession() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.isTerminal) {
      // 완료/중단된 세션은 복원 대상이 아니므로 저장본을 정리한다.
      unawaited(_store.clear());
      return;
    }
    final state = controller.state;
    final timer = controller.timer;
    if (state.stepIndex == _persistedStepIndex &&
        state.sessionStatus == _persistedSessionStatus &&
        timer.status == _persistedTimerStatus &&
        timer.effectiveDuration == _persistedTimerEffective) {
      return;
    }
    _persistedStepIndex = state.stepIndex;
    _persistedSessionStatus = state.sessionStatus;
    _persistedTimerStatus = timer.status;
    _persistedTimerEffective = timer.effectiveDuration;
    final snapshot = timer.snapshot();
    unawaited(
      _store.save(
        PersistedCookingSession(
          recipeTitle: widget.recipe.title,
          servings: widget.servings,
          stepIndex: state.stepIndex,
          sessionStatus: state.sessionStatus.name,
          timerOriginalMs: snapshot.originalDuration.inMilliseconds,
          timerEffectiveMs: snapshot.effectiveDuration.inMilliseconds,
          timerRemainingMs: snapshot.remaining.inMilliseconds,
          timerStatus: snapshot.status.name,
          savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      // 알림 초기화(최초 1회 권한 요청)가 끝나면 바로 세션이 시작된다.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CookingScreen(
      controller: controller,
      recipeName: '${widget.recipe.title} · ${widget.servings}인분',
      onComplete: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ReviewScreen(recipe: widget.recipe),
          ),
        );
      },
      onAbort: () => Navigator.of(context).pop(),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '조리 후 리뷰',
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
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
            Expanded(
              child: Wrap(
                spacing: 2,
                children: [
                  for (var i = 1; i <= 5; i++)
                    PressableScale(
                      scale: 0.8,
                      child: IconButton(
                        onPressed: () => setState(() => rating = i),
                        icon: AnimatedSwitcher(
                          duration: AppMotion.fast,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            Icons.star_rounded,
                            key: ValueKey(i <= rating),
                            color: i <= rating
                                ? AppColors.accent
                                : AppColors.line,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$rating / 5',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SectionTitle('이번 조리 요약'),
        const InfoStrip(
          icon: Icons.summarize_rounded,
          title: '2인분 · 나 맞춤 기반 · 25분 소요',
          body: '설탕 생략 · 간장 3큰술 → 2.5큰술 · 조리 시간 4분 → 5분',
        ),
        const SectionTitle('한 줄 메모'),
        const TextField(
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(hintText: '텍스트 입력 또는 음성 메모'),
        ),
        const SectionTitle('자동으로 기록한 변경'),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [Pill('설탕 생략'), Pill('간장 50%'), Pill('2분 추가')],
        ),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SaveChoiceScreen(recipe: widget.recipe),
              ),
            );
          },
          child: const Text('레시피 메모리에 저장'),
        ),
      ),
    );
  }
}

class SaveChoiceScreen extends StatefulWidget {
  const SaveChoiceScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<SaveChoiceScreen> createState() => _SaveChoiceScreenState();
}

class _SaveChoiceScreenState extends State<SaveChoiceScreen> {
  int choice = 0;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '어떻게 저장할까요?',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      children: [
        const Text(
          '이번 변경을 다음 조리에 어떻게 반영할지 선택하세요.',
          style: TextStyle(color: AppColors.slate),
        ),
        const SizedBox(height: 18),
        _SaveOption(
          icon: Icons.check_circle_rounded,
          title: '나 맞춤 업데이트',
          subtitle: '다음 조리의 기본값으로 사용',
          selected: choice == 0,
          onTap: () => setState(() => choice = 0),
        ),
        _SaveOption(
          icon: Icons.add_circle_outline_rounded,
          title: '새 변형으로 저장',
          subtitle: '현재 나 맞춤은 유지하고 별도 버전 생성',
          selected: choice == 1,
          onTap: () => setState(() => choice = 1),
        ),
        const SectionTitle('저장되는 정보'),
        const Text(
          '날짜 · 인분 · 변경사항 · 만족도 · 코멘트 · 완성 사진',
          style: TextStyle(color: AppColors.slate),
        ),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const MainShell()),
              (route) => false,
            );
          },
          child: const Text('선택한 방식으로 저장'),
        ),
      ),
    );
  }
}

class _SaveOption extends StatelessWidget {
  const _SaveOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.inner),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : AppColors.card,
            borderRadius: BorderRadius.circular(AppShape.inner),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: selected ? AppColors.accent : AppColors.slate,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            trailing: AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('checked'),
                      color: AppColors.accent,
                    )
                  : const SizedBox.shrink(key: ValueKey('unchecked')),
            ),
          ),
        ),
      ),
    );
  }
}
