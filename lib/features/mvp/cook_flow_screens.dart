import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'main_shell.dart';
import 'mock_data.dart';
import 'mvp_widgets.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final canCook = recipe.steps.isNotEmpty;

    return PageShell(
      title: '레시피 상세',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.star_border_rounded),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
      children: [
        Hero(
          tag: 'recipe-image-${recipe.title}',
          child: const FoodPreview(size: double.infinity),
        ),
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
          '${recipe.minutes}분 · ${recipe.difficulty} · 2인분 · ★ ${recipe.rating}',
          style: const TextStyle(color: AppColors.slate),
        ),
        const SectionTitle('필요한 재료'),
        if (recipe.ingredients.isEmpty)
          const InfoStrip(
            icon: Icons.info_outline_rounded,
            title: '상세 재료 준비 중',
            body: '현재 MVP에서는 두부 조림 레시피를 중심으로 조리 흐름을 확인할 수 있어요.',
          )
        else
          ...recipe.ingredients.map(
            (item) => CheckboxListTile(
              value: false,
              onChanged: (_) {},
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${item.name} ${item.amount}'),
              subtitle: item.note.isEmpty ? null : Text(item.note),
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
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                child: Text('${i + 1}'),
              ),
              title: Text(
                recipe.steps[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('약 ${recipe.steps[i].minutes}분'),
            ),
      ],
      bottom: PressableScale(
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
                child: AnimatedSwitcher(
                  duration: AppMotion.short,
                  switchInCurve: AppMotion.easeOut,
                  switchOutCurve: AppMotion.easeOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$servings인분',
                    key: ValueKey(servings),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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

class CookSessionScreen extends StatefulWidget {
  const CookSessionScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  final Recipe recipe;
  final int servings;

  @override
  State<CookSessionScreen> createState() => _CookSessionScreenState();
}

class _CookSessionScreenState extends State<CookSessionScreen> {
  int step = 1;

  @override
  Widget build(BuildContext context) {
    final current = widget.recipe.steps[step - 1];
    final isLast = step == widget.recipe.steps.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          '${widget.recipe.title} · ${widget.servings}인분',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.pause_rounded)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Text(
                  '$step / ${widget.recipe.steps.length} 단계',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '자동 저장됨',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(end: step / widget.recipe.steps.length),
              duration: AppMotion.medium,
              curve: AppMotion.easeInOut,
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: AppMotion.easeOut,
              switchOutCurve: AppMotion.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(step),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FoodPreview(size: double.infinity),
                  const SizedBox(height: 18),
                  Text(
                    current.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current.description,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('남은 시간', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    '0${current.minutes}:00',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PressableScale(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('타이머 시작'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const InfoStrip(
              icon: Icons.mic_rounded,
              title: '"얼마나 익었나요?"',
              body: '말하면 익힘 상태를 확인하고 다음 행동을 안내해요.',
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [Pill('재료 문제'), Pill('반복'), Pill('타이머'), Pill('도움')],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: PressableScale(
          child: FilledButton(
            onPressed: () {
              if (isLast) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(recipe: widget.recipe),
                  ),
                );
              } else {
                setState(() => step++);
              }
            },
            child: Text(isLast ? '조리 완료' : '다음 단계'),
          ),
        ),
      ),
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
                            color: i <= rating ? AppColors.ink : AppColors.line,
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
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.short,
          curve: AppMotion.easeInOut,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: selected ? AppColors.success : AppColors.slate,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
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
                      color: AppColors.ink,
                    )
                  : const SizedBox.shrink(key: ValueKey('unchecked')),
            ),
          ),
        ),
      ),
    );
  }
}
