import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/identity/uuid_v4.dart';
import '../cooking/application/cooking_ports.dart';
import '../cooking/application/cooking_session_store.dart';
import '../cooking/application/timer_controller.dart';
import '../cooking/domain/cooking_setup_snapshot.dart';
import '../cooking/domain/cooking_session_state.dart';
import '../cooking/presentation/timer_alarm_provider.dart';
import '../cooking/presentation/widgets/help_question_sheet.dart';
import '../recipe/data/recipe_api.dart';
import '../recipe/domain/recipe.dart';
import '../review/data/review_api.dart';
import 'main_shell.dart';
import 'mvp_widgets.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  late bool _isFavorite;
  bool _savingFavorite = false;

  Recipe get recipe => widget.recipe;

  @override
  void initState() {
    super.initState();
    _isFavorite = recipe.favorite;
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    setState(() => _savingFavorite = true);
    try {
      if (_isFavorite) {
        await _recipeRepository.removeFavorite(recipe.id);
      } else {
        await _recipeRepository.addFavorite(recipe.id);
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
    } on RecipeApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _savingFavorite = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCook = recipe.steps.isNotEmpty;

    return PopScope(
      canPop: !_savingFavorite,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.surface,
              leading: _CircleAction(
                icon: Icons.chevron_left_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                _CircleAction(
                  icon: _isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  onTap: _savingFavorite ? null : _toggleFavorite,
                ),
                const SizedBox(width: 6),
                const _CircleAction(icon: Icons.ios_share_rounded),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(image: recipe.imageUrl, radius: 0),
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
                      recipe.description,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                    const SizedBox(height: 18),
                    // 핵심 스탯 타일 3개
                    Row(
                      children: [
                        _StatTile(
                          icon: Icons.schedule_rounded,
                          label: '타이머 합계',
                          value: '${recipe.timerMinutes}분',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.format_list_numbered_rounded,
                          label: '조리 단계',
                          value: '${recipe.steps.length}단계',
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          icon: Icons.people_alt_rounded,
                          label: '기준',
                          value:
                              '${recipe.baseServings.toStringAsFixed(recipe.baseServings % 1 == 0 ? 0 : 1)}인분',
                        ),
                      ],
                    ),
                    const SectionTitle('필요한 재료'),
                    if (recipe.ingredients.isEmpty)
                      const InfoStrip(
                        icon: Icons.info_outline_rounded,
                        title: '상세 재료 준비 중',
                        body: '이 레시피에는 아직 등록된 재료가 없어요.',
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
                      title: recipe.hasPersonalVersion
                          ? '나 맞춤 버전 있음'
                          : '나 맞춤 버전 없음',
                      body: recipe.memorySummary,
                    ),
                    const SectionTitle('조리 순서'),
                    if (recipe.steps.isEmpty)
                      const InfoStrip(
                        icon: Icons.construction_rounded,
                        title: '조리 단계 준비 중',
                        body: '이 레시피에는 아직 등록된 조리 단계가 없어요.',
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            recipe.steps[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            recipe.steps[i].timerSeconds == null
                                ? '타이머 없음'
                                : '약 ${recipe.steps[i].minutes}분',
                          ),
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
      ),
    );
  }
}

/// SliverAppBar 위에 얹는 반투명 원형 아이콘 버튼.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PressableScale(
        child: GestureDetector(
          onTap: onTap,
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
                    const SizedBox(height: 2),
                    Text(
                      item.requirementLabel,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item.amountLabel,
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
  const CookSetupScreen({
    super.key,
    required this.recipe,
    this.recipeRepository,
    this.sessionAlarm,
  });

  final Recipe recipe;
  final RecipeRepository? recipeRepository;
  final TimerAlarmPort? sessionAlarm;

  @override
  State<CookSetupScreen> createState() => _CookSetupScreenState();
}

class _CookSetupScreenState extends State<CookSetupScreen> {
  late int servings;
  late final RecipeRepository _recipeRepository;
  late List<_IngredientSetupDraft> _ingredients;
  late List<CookStep> _steps;
  List<PersonalRecipeVersionSummary> _personalVersions = const [];
  PersonalRecipeVersionDetail? _personalVersion;
  bool _loadingPersonalVersion = false;
  bool _usePersonalVersion = false;
  String? _personalVersionError;

  @override
  void initState() {
    super.initState();
    _recipeRepository = widget.recipeRepository ?? RecipeRepository();
    servings = widget.recipe.baseServings.round().clamp(1, 99);
    _applySelectedRecipe();
    unawaited(_loadPersonalVersions());
  }

  Future<void> _loadPersonalVersions() async {
    if (!widget.recipe.hasPersonalVersion) {
      return;
    }
    setState(() {
      _loadingPersonalVersion = true;
      _personalVersionError = null;
    });
    try {
      final versions = await _recipeRepository.findPersonalVersions(
        widget.recipe.id,
      );
      if (!mounted) return;
      setState(() {
        _personalVersions = versions;
        _loadingPersonalVersion = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingPersonalVersion = false;
        _personalVersionError = '나 맞춤 버전을 불러오지 못해 기본 레시피로 진행해요.';
      });
    }
  }

  Future<void> _selectPersonalVersion(
    PersonalRecipeVersionSummary? selected,
  ) async {
    if (selected == null) {
      if (!_usePersonalVersion) return;
      setState(() {
        _usePersonalVersion = false;
        _personalVersion = null;
        _personalVersionError = null;
        _applySelectedRecipe();
      });
      return;
    }
    if (_personalVersion?.id == selected.id) return;
    setState(() {
      _loadingPersonalVersion = true;
      _personalVersionError = null;
    });
    try {
      final version = await _recipeRepository.findPersonalVersionDetail(
        selected.id,
      );
      if (version.steps.isEmpty) {
        throw const RecipeApiException('나 맞춤 버전에 조리 단계가 없습니다.');
      }
      if (!mounted) return;
      setState(() {
        _personalVersion = version;
        _usePersonalVersion = true;
        _loadingPersonalVersion = false;
        _applySelectedRecipe();
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _usePersonalVersion = false;
        _personalVersion = null;
        _loadingPersonalVersion = false;
        _personalVersionError = '이 버전을 불러오지 못했어요. 기본 레시피를 이용해주세요.';
        _applySelectedRecipe();
      });
    }
  }

  void _applySelectedRecipe() {
    final personal = _usePersonalVersion ? _personalVersion : null;
    final sourceIngredients =
        personal?.ingredients ?? widget.recipe.ingredients;
    _steps = List<CookStep>.of(personal?.steps ?? widget.recipe.steps);
    final scale = servings / _safeBaseServings;
    _ingredients = sourceIngredients
        .map(
          (ingredient) => _IngredientSetupDraft(
            originalIngredientId: ingredient.originalIngredientId,
            originalName: ingredient.name,
            name: ingredient.name,
            amount: ingredient.amount == null
                ? null
                : ingredient.amount! * scale,
            baselineAmount: ingredient.amount == null
                ? null
                : ingredient.amount! * scale,
            unit: ingredient.unit,
            isRequired: ingredient.isRequired,
          ),
        )
        .toList(growable: false);
  }

  double get _safeBaseServings =>
      widget.recipe.baseServings > 0 ? widget.recipe.baseServings : 1;

  void _changeServings(int delta) {
    final next = (servings + delta).clamp(1, 99);
    if (next == servings) return;
    final scale = next / servings;
    setState(() {
      servings = next;
      _ingredients = _ingredients
          .map((ingredient) => ingredient.scaled(scale))
          .toList(growable: false);
    });
  }

  CookingSetupSnapshot _buildSnapshot() {
    return CookingSetupSnapshot(
      recipeId: widget.recipe.id,
      title: widget.recipe.title,
      description: widget.recipe.description,
      imageUrl: widget.recipe.imageUrl,
      baseServings: widget.recipe.baseServings,
      targetServings: servings,
      source: _usePersonalVersion
          ? CookingRecipeSource.personal
          : CookingRecipeSource.base,
      personalVersionId: _usePersonalVersion ? _personalVersion?.id : null,
      ingredients: _ingredients
          .map((ingredient) => ingredient.toSnapshot())
          .toList(growable: false),
      steps: _steps
          .map(
            (step) => CookingSetupStep(
              originalStepId: step.originalStepId,
              stepIndex: step.stepIndex,
              instruction: step.instruction,
              timerSeconds: step.timerSeconds,
              cautionNote: step.cautionNote,
              imageUrl: step.imageUrl,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setupLocked = _loadingPersonalVersion;

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
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('기본'),
              selected: !_usePersonalVersion,
              onSelected: setupLocked
                  ? null
                  : (_) => unawaited(_selectPersonalVersion(null)),
            ),
            for (final version in _personalVersions)
              ChoiceChip(
                label: Text('v${version.versionNumber}'),
                selected: _personalVersion?.id == version.id,
                onSelected: setupLocked
                    ? null
                    : (_) => unawaited(_selectPersonalVersion(version)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        InfoStrip(
          icon: Icons.auto_awesome_rounded,
          title: _loadingPersonalVersion
              ? '개인 버전을 불러오는 중'
              : _usePersonalVersion
              ? _personalVersion!.title
              : '기본 레시피',
          body:
              _personalVersionError ??
              (_loadingPersonalVersion
                  ? '최근 개인 레시피 버전을 확인하고 있어요.'
                  : _usePersonalVersion
                  ? (_personalVersion!.summary.isEmpty
                        ? '저장된 나 맞춤 재료와 조리 단계를 적용했어요.'
                        : _personalVersion!.summary)
                  : widget.recipe.memorySummary),
        ),
        const SectionTitle('몇 인분인가요?'),
        Row(
          children: [
            PressableScale(
              child: IconButton.filledTonal(
                onPressed: !setupLocked && servings > 1
                    ? () => _changeServings(-1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$servings인분',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            PressableScale(
              child: IconButton.filled(
                onPressed: setupLocked ? null : () => _changeServings(1),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        const SectionTitle('재료 변경'),
        for (final (index, ingredient) in _ingredients.indexed)
          Card(
            child: ListTile(
              title: Text(
                ingredient.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  Flexible(
                    child: Text(
                      ingredient.omitted
                          ? '이번 조리에서 생략'
                          : ingredient.amountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ingredient.isSubstituted) ...[
                    const SizedBox(width: 6),
                    const Pill('대체'),
                  ],
                ],
              ),
              trailing: TextButton(
                onPressed: setupLocked
                    ? null
                    : () => _openIngredientSheet(context, index),
                child: const Text('수정'),
              ),
            ),
          ),
        const SectionTitle('이번 조리 요약'),
        InfoStrip(
          icon: Icons.check_circle_outline_rounded,
          title: '$servings인분 · ${_usePersonalVersion ? '나 맞춤' : '기본'}',
          body:
              '사용 재료 ${_ingredients.where((item) => !item.omitted).length}개'
              ' · 생략 ${_ingredients.where((item) => item.omitted).length}개'
              ' · 조리 ${_steps.length}단계',
        ),
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: setupLocked
              ? null
              : () {
                  final snapshot = _buildSnapshot();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CookSessionScreen(
                        recipe: snapshot.toRecipe(),
                        servings: servings,
                        setupSnapshot: snapshot,
                        alarm: widget.sessionAlarm,
                      ),
                    ),
                  );
                },
          child: Text(setupLocked ? '나 맞춤 버전 불러오는 중' : '이 설정으로 조리 시작'),
        ),
      ),
    );
  }

  Future<void> _openIngredientSheet(BuildContext context, int index) async {
    final ingredient = _ingredients[index];
    var mode = ingredient.omitted
        ? _IngredientEditMode.omit
        : ingredient.isSubstituted
        ? _IngredientEditMode.substitute
        : _IngredientEditMode.amount;
    var amount = ingredient.amount;
    var replacementName = ingredient.isSubstituted ? ingredient.name : '';
    String? validationMessage;

    final result = await showModalBottomSheet<_IngredientEditResult>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final amountLabel = _formatAmount(amount, ingredient.unit);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ingredient.originalName} · ${ingredient.amountLabel}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('양 조절'),
                          selected: mode == _IngredientEditMode.amount,
                          onSelected: (_) => setSheetState(
                            () => mode = _IngredientEditMode.amount,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('대체'),
                          selected: mode == _IngredientEditMode.substitute,
                          onSelected: (_) => setSheetState(
                            () => mode = _IngredientEditMode.substitute,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('생략'),
                          selected: mode == _IngredientEditMode.omit,
                          onSelected: (_) => setSheetState(
                            () => mode = _IngredientEditMode.omit,
                          ),
                        ),
                      ],
                    ),
                    if (ingredient.isSubstituted) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(
                              _IngredientEditResult(
                                mode: _IngredientEditMode.restoreOriginal,
                                amount: amount,
                                replacementName: '',
                              ),
                            );
                          },
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(
                            '기본 재료(${ingredient.originalName})로 되돌리기',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (mode == _IngredientEditMode.substitute) ...[
                      TextFormField(
                        initialValue: replacementName,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '대체할 재료',
                          hintText: '예: 쪽파',
                        ),
                        onChanged: (value) => setSheetState(() {
                          replacementName = value;
                          validationMessage = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      const InfoStrip(
                        icon: Icons.lightbulb_outline_rounded,
                        title: '추천 대체재는 준비 중이에요',
                        body: '지금은 사용할 재료를 직접 입력해주세요.',
                      ),
                    ] else if (mode == _IngredientEditMode.omit) ...[
                      InfoStrip(
                        icon: ingredient.isRequired
                            ? Icons.warning_amber_rounded
                            : Icons.remove_circle_outline_rounded,
                        title: ingredient.isRequired
                            ? '필수 재료를 생략할까요?'
                            : '이번 조리에서 생략해요',
                        body: ingredient.isRequired
                            ? '맛과 조리 결과가 달라질 수 있어요.'
                            : '조리 시작 전까지 다시 변경할 수 있어요.',
                      ),
                    ] else ...[
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: amount == null || (amount ?? 0) <= 0
                                ? null
                                : () => setSheetState(() {
                                    amount = _adjustAmount(
                                      amount!,
                                      ingredient.unit,
                                      -1,
                                    );
                                  }),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Expanded(
                            child: Text(
                              amountLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: amount == null
                                ? null
                                : () => setSheetState(() {
                                    amount = _adjustAmount(
                                      amount!,
                                      ingredient.unit,
                                      1,
                                    );
                                  }),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const InfoStrip(
                        icon: Icons.calculate_rounded,
                        title: '이 재료의 양만 조절해요',
                        body: '다른 양념 비율은 자동으로 바꾸지 않아요.',
                      ),
                    ],
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    PressableScale(
                      child: FilledButton(
                        onPressed: () {
                          final replacement = replacementName.trim();
                          if (mode == _IngredientEditMode.substitute &&
                              replacement.isEmpty) {
                            setSheetState(
                              () => validationMessage = '대체할 재료를 입력해주세요.',
                            );
                            return;
                          }
                          Navigator.of(context).pop(
                            _IngredientEditResult(
                              mode: mode,
                              amount: amount,
                              replacementName: replacement,
                            ),
                          );
                        },
                        child: const Text('적용'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _ingredients[index] = switch (result.mode) {
        _IngredientEditMode.amount => ingredient.copyWith(
          name: ingredient.name,
          amount: result.amount,
          omitted: false,
        ),
        _IngredientEditMode.substitute => ingredient.copyWith(
          name: result.replacementName,
          amount: result.amount,
          omitted: false,
        ),
        _IngredientEditMode.omit => ingredient.copyWith(omitted: true),
        _IngredientEditMode.restoreOriginal => ingredient.copyWith(
          name: ingredient.originalName,
          amount: result.amount,
          omitted: false,
        ),
      };
    });
  }
}

enum _IngredientEditMode { amount, substitute, omit, restoreOriginal }

final class _IngredientEditResult {
  const _IngredientEditResult({
    required this.mode,
    required this.amount,
    required this.replacementName,
  });

  final _IngredientEditMode mode;
  final double? amount;
  final String replacementName;
}

final class _IngredientSetupDraft {
  const _IngredientSetupDraft({
    required this.originalIngredientId,
    required this.originalName,
    required this.name,
    required this.amount,
    required this.baselineAmount,
    required this.unit,
    required this.isRequired,
    this.omitted = false,
  });

  static const _unset = Object();

  final String? originalIngredientId;
  final String originalName;
  final String name;
  final double? amount;
  final double? baselineAmount;
  final String unit;
  final bool isRequired;
  final bool omitted;

  bool get isSubstituted => originalName != name;
  String get amountLabel => _formatAmount(amount, unit);

  _IngredientSetupDraft scaled(double scale) => _IngredientSetupDraft(
    originalIngredientId: originalIngredientId,
    originalName: originalName,
    name: name,
    amount: amount == null ? null : amount! * scale,
    baselineAmount: baselineAmount == null ? null : baselineAmount! * scale,
    unit: unit,
    isRequired: isRequired,
    omitted: omitted,
  );

  _IngredientSetupDraft copyWith({
    String? name,
    Object? amount = _unset,
    bool? omitted,
  }) {
    return _IngredientSetupDraft(
      originalIngredientId: originalIngredientId,
      originalName: originalName,
      name: name ?? this.name,
      amount: identical(amount, _unset) ? this.amount : amount as double?,
      baselineAmount: baselineAmount,
      unit: unit,
      isRequired: isRequired,
      omitted: omitted ?? this.omitted,
    );
  }

  CookingSetupIngredient toSnapshot() => CookingSetupIngredient(
    originalIngredientId: originalIngredientId,
    originalName: originalName,
    name: name,
    amount: amount,
    baselineAmount: baselineAmount,
    unit: unit,
    isRequired: isRequired,
    omitted: omitted,
  );
}

String _formatAmount(double? amount, String unit) {
  if (amount == null) return unit;
  final value = amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$value$unit';
}

double _adjustAmount(double amount, String unit, int direction) {
  final step = switch (unit.toLowerCase()) {
    'g' || 'ml' => amount >= 100 ? 10.0 : 5.0,
    _ => 0.5,
  };
  final adjusted = amount + step * direction;
  return adjusted < 0 ? 0 : adjusted;
}

class CookSessionScreen extends StatefulWidget {
  const CookSessionScreen({
    super.key,
    required this.recipe,
    required this.servings,
    this.setupSnapshot,
    this.restoredSession,
    this.alarm,
    this.advicePort,
  });

  final Recipe recipe;
  final int servings;
  final CookingSetupSnapshot? setupSnapshot;

  /// 홈의 "이어서 조리하기"로 진입할 때 전달되는 저장 세션.
  final PersistedCookingSession? restoredSession;

  /// 테스트에서 플랫폼 알림 초기화를 대체하기 위한 주입 지점.
  final TimerAlarmPort? alarm;

  /// 도움 질문에 답하는 포트. AI 파트가 완성되면 실제 구현으로 교체한다.
  final ExceptionAdvicePort? advicePort;

  @override
  State<CookSessionScreen> createState() => _CookSessionScreenState();
}

class _CookSessionScreenState extends State<CookSessionScreen>
    with WidgetsBindingObserver {
  final CookingSessionStore _store = const CookingSessionStore();

  int step = 1;
  late final String _sessionId;
  final Map<int, int> _timerSecondsByStep = <int, int>{};

  // 도움 질문(음성 폴백) 상태. 답변은 현재 단계에 묶이므로 단계가 바뀌면 버린다.
  late final ExceptionAdvicePort _advice =
      widget.advicePort ?? DemoExceptionAdvicePort();
  String? _helpAnswer;
  bool _helpLoading = false;
  int _helpRequestVersion = 0;

  // 원래 디자인은 그대로 두고 시계(타이머)만 실제로 동작시킨다.
  // 기본 클럭이 WallAnchoredMonotonicClock이라 화면이 꺼져도 시간이 이어진다.
  final LocalTimerController _timer = LocalTimerController();
  TimerAlarmPort? _alarm;
  TimerStatus _lastStatus = TimerStatus.idle;

  // 마지막으로 저장한 상태. 타이머가 틱마다 알림을 보내므로 의미 있는
  // 변화(단계·타이머 상태·연장)가 있을 때만 저장한다. 남은 시간은 저장
  // 시각과 함께 기록해 복원 시 재계산하므로 매 틱 저장이 필요 없다.
  int? _persistedStep;
  TimerStatus? _persistedTimerStatus;
  Duration? _persistedTimerEffective;

  // 조리 완료 후 화면 전환 중에도 타이머 콜백이 살아 있으므로,
  // 정리한 저장본을 다시 쓰지 않도록 완료 이후에는 저장을 막는다.
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer.addListener(_onTimerChanged);
    final restored = widget.restoredSession;
    _sessionId = restored?.sessionId ?? generateUuidV4();
    _timerSecondsByStep.addAll(
      restored?.timerSecondsByStep ?? const <int, int>{},
    );
    if (restored == null) {
      _resetTimerForStep();
    } else {
      // 손상된 저장값이 들어와도 단계 범위 안으로 보정한다.
      final restoredStep = restored.stepIndex + 1;
      step = restoredStep < 1
          ? 1
          : restoredStep > widget.recipe.steps.length
          ? widget.recipe.steps.length
          : restoredStep;
      // 저장 이후 흐른 시간이 차감된 스냅샷으로 타이머를 되살린다.
      _timer.restore(restored.timerSnapshotAt(DateTime.now()));
      _lastStatus = _timer.status;
    }
    unawaited(_initAlarm());
    _persist();
  }

  Future<void> _initAlarm() async {
    // 백그라운드 알림용 로컬 알림을 한 번 초기화(권한 요청 포함)한다.
    final alarm = widget.alarm ?? await resolveTimerAlarm();
    if (mounted) {
      _alarm = alarm;
      // 복원된 타이머가 이미 실행 중이면 종료 알림을 다시 예약한다.
      _scheduleAlarm();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면을 다시 켜면 잠든 사이 흐른 시간을 반영해 남은 시간을 재계산한다.
    if (state == AppLifecycleState.resumed) {
      _timer.sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.removeListener(_onTimerChanged);
    unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
    _timer.dispose();
    super.dispose();
  }

  void _onTimerChanged() {
    final status = _timer.status;
    if (status == TimerStatus.elapsed && _lastStatus != TimerStatus.elapsed) {
      _alarm?.signalTimerElapsed();
      unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
    }
    _lastStatus = status;
    _persist();
  }

  void _persist() {
    if (_completed) {
      return;
    }
    if (step == _persistedStep &&
        _timer.status == _persistedTimerStatus &&
        _timer.effectiveDuration == _persistedTimerEffective) {
      return;
    }
    _persistedStep = step;
    _persistedTimerStatus = _timer.status;
    _persistedTimerEffective = _timer.effectiveDuration;
    final snapshot = _timer.snapshot();
    unawaited(
      _store.save(
        PersistedCookingSession(
          sessionId: _sessionId,
          recipeId: widget.recipe.id,
          recipeTitle: widget.recipe.title,
          servings: widget.servings,
          setupSnapshot: widget.setupSnapshot,
          stepIndex: step - 1,
          sessionStatus: CookingSessionStatus.cooking.name,
          timerOriginalMs: snapshot.originalDuration.inMilliseconds,
          timerEffectiveMs: snapshot.effectiveDuration.inMilliseconds,
          timerRemainingMs: snapshot.remaining.inMilliseconds,
          timerStatus: snapshot.status.name,
          savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          timerSecondsByStep: Map.unmodifiable(_timerSecondsByStep),
        ),
      ),
    );
  }

  void _resetTimerForStep() {
    _timerSecondsByStep.remove(step - 1);
    final duration = widget.recipe.steps[step - 1].timerDuration;
    _timer.reset(duration, autoStart: false);
    _lastStatus = _timer.status;
    unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
  }

  void _scheduleAlarm() {
    if (_timer.status == TimerStatus.running &&
        _timer.remaining > Duration.zero) {
      unawaited(
        _alarm?.scheduleTimerElapsed(DateTime.now().add(_timer.remaining)) ??
            Future<void>.value(),
      );
    }
  }

  void _toggleTimer() {
    switch (_timer.status) {
      case TimerStatus.idle:
        _timer.start();
        _scheduleAlarm();
      case TimerStatus.paused:
        _timer.resume();
        _scheduleAlarm();
      case TimerStatus.running:
        _timer.pause();
        unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
      case TimerStatus.elapsed:
        break;
    }
  }

  void _addMinute() {
    // add()는 정지/종료 상태여도 타이머를 다시 진행시킨다.
    _timerSecondsByStep[step - 1] =
        _timer.effectiveDuration.inSeconds +
        const Duration(minutes: 1).inSeconds;
    _timer.add(const Duration(minutes: 1));
    _scheduleAlarm();
  }

  Future<void> _openHelpSheet() async {
    final question = await HelpQuestionSheet.show(context);
    if (question == null || !mounted) {
      return;
    }
    final requestVersion = ++_helpRequestVersion;
    final requestedStep = step;
    setState(() {
      _helpLoading = true;
      _helpAnswer = null;
    });
    ExceptionAdvice advice;
    try {
      advice = await _advice.requestAdvice(
        ExceptionAdviceContext(
          sessionId: 'mvp-local',
          recipeId: widget.recipe.title,
          recipeVersionId: 'mvp',
          stepIndex: requestedStep - 1,
          requestContextVersion: requestVersion,
          instruction: widget.recipe.steps[requestedStep - 1].description,
          remaining: _timer.remaining,
          utterance: question,
          recentEvents: const [],
        ),
      );
    } catch (_) {
      if (!mounted ||
          requestVersion != _helpRequestVersion ||
          step != requestedStep) {
        return;
      }
      setState(() {
        _helpLoading = false;
        _helpAnswer = '답변을 불러오지 못했어요. 버튼과 타이머는 계속 사용할 수 있어요.';
      });
      return;
    }
    // 기다리는 사이 단계가 바뀌었으면 낡은 답변을 표시하지 않는다.
    if (!mounted ||
        requestVersion != _helpRequestVersion ||
        step != requestedStep) {
      return;
    }
    setState(() {
      _helpLoading = false;
      _helpAnswer = advice.message;
    });
  }

  String _timerLabel(int stepMinutes) {
    if (stepMinutes <= 0) {
      return '타이머 없음';
    }
    return switch (_timer.status) {
      TimerStatus.idle => '타이머 시작',
      TimerStatus.running => '일시정지',
      TimerStatus.paused => '계속',
      TimerStatus.elapsed => '시간 종료',
    };
  }

  static String _formatRemaining(Duration remaining) {
    final totalSeconds = (remaining.inMilliseconds / 1000).ceil().clamp(
      0,
      5999,
    );
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.recipe.steps[step - 1];
    final isLast = step == widget.recipe.steps.length;
    final hasTimer = current.timerDuration > Duration.zero;

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
            LinearProgressIndicator(value: step / widget.recipe.steps.length),
            const SizedBox(height: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FoodImage(
                  image: current.imageUrl.isNotEmpty
                      ? current.imageUrl
                      : widget.recipe.imageUrl,
                  width: double.infinity,
                  height: 210,
                  radius: AppShape.container,
                ),
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
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppShape.container),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 22,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    '남은 시간',
                    style: TextStyle(color: Color(0xB3FFFFFF)),
                  ),
                  const SizedBox(height: 8),
                  // 시계만 실제로 동작하는 부분: 타이머 상태에 맞춰 매초 갱신된다.
                  AnimatedBuilder(
                    animation: _timer,
                    builder: (context, _) => Text(
                      _formatRemaining(_timer.remaining),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _timer,
                    builder: (context, _) => PressableScale(
                      child: FilledButton(
                        onPressed:
                            hasTimer && _timer.status != TimerStatus.elapsed
                            ? _toggleTimer
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(_timerLabel(current.minutes)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 시계 보조 컨트롤: 1분 추가 / 리셋. 다크 카드에 맞춘 아웃라인 버튼.
                  AnimatedBuilder(
                    animation: _timer,
                    builder: (context, _) {
                      final style = OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        minimumSize: const Size.fromHeight(44),
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: hasTimer ? _addMinute : null,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('1분 추가'),
                              style: style,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  hasTimer && _timer.status != TimerStatus.idle
                                  ? _resetTimerForStep
                                  : null,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('리셋'),
                              style: style,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PressableScale(
              child: GestureDetector(
                key: const Key('help-request'),
                onTap: _openHelpSheet,
                child: const InfoStrip(
                  icon: Icons.mic_rounded,
                  title: '"얼마나 익었나요?"',
                  body: '말하면 익힘 상태를 확인하고 다음 행동을 안내해요. 눌러서 질문을 입력할 수도 있어요.',
                ),
              ),
            ),
            if (_helpLoading) ...[
              const SizedBox(height: 12),
              const InfoStrip(
                icon: Icons.hourglass_top_rounded,
                title: '답변 준비 중',
                body: '현재 단계에 맞는 답을 확인하고 있어요.',
              ),
            ] else if (_helpAnswer case final String answer) ...[
              const SizedBox(height: 12),
              InfoStrip(
                icon: Icons.support_agent_rounded,
                title: '도움 답변',
                body: answer,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: PressableScale(
          child: FilledButton(
            onPressed: () {
              if (isLast) {
                // 후기 저장이 성공하기 전까지 동일 세션으로 재시도할 수 있게 보존한다.
                _completed = true;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(
                      setupSnapshot: _reviewSnapshot(),
                      clientSessionId: _sessionId,
                      cookedAt: DateTime.now(),
                      timerSecondsByStep: Map.unmodifiable(_timerSecondsByStep),
                    ),
                  ),
                );
              } else {
                _helpRequestVersion++;
                setState(() {
                  step++;
                  _helpAnswer = null;
                  _helpLoading = false;
                });
                _resetTimerForStep();
                _persist();
              }
            },
            child: Text(isLast ? '조리 완료' : '다음 단계'),
          ),
        ),
      ),
    );
  }

  CookingSetupSnapshot _reviewSnapshot() {
    final snapshot = widget.setupSnapshot;
    if (snapshot != null) return snapshot;
    return CookingSetupSnapshot(
      recipeId: widget.recipe.id,
      title: widget.recipe.title,
      description: widget.recipe.description,
      imageUrl: widget.recipe.imageUrl,
      baseServings: widget.recipe.baseServings,
      targetServings: widget.servings,
      source: CookingRecipeSource.base,
      personalVersionId: null,
      ingredients: [
        for (final ingredient in widget.recipe.ingredients)
          CookingSetupIngredient(
            originalIngredientId: ingredient.originalIngredientId,
            originalName: ingredient.name,
            name: ingredient.name,
            amount: ingredient.amount,
            baselineAmount: ingredient.amount,
            unit: ingredient.unit,
            isRequired: ingredient.isRequired,
          ),
      ],
      steps: [
        for (final step in widget.recipe.steps)
          CookingSetupStep(
            originalStepId: step.originalStepId,
            stepIndex: step.stepIndex,
            instruction: step.instruction,
            timerSeconds: step.timerSeconds,
            cautionNote: step.cautionNote,
            imageUrl: step.imageUrl,
          ),
      ],
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.setupSnapshot,
    required this.clientSessionId,
    required this.cookedAt,
    required this.timerSecondsByStep,
    this.reviewRepository,
  });

  final CookingSetupSnapshot setupSnapshot;
  final String clientSessionId;
  final DateTime cookedAt;
  final Map<int, int> timerSecondsByStep;
  final ReviewRepository? reviewRepository;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;
  late final ReviewRepository _reviewRepository;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _nextTimeController = TextEditingController();
  bool _saving = false;
  ReviewSaveResult? _saved;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _reviewRepository = widget.reviewRepository ?? ReviewRepository();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _nextTimeController.dispose();
    super.dispose();
  }

  List<String> get _changeLabels {
    final changes = <String>[];
    for (final ingredient in widget.setupSnapshot.ingredients) {
      if (ingredient.omitted) {
        changes.add('${ingredient.originalName} 생략');
      } else if (ingredient.isSubstituted) {
        changes.add('${ingredient.originalName} → ${ingredient.name}');
      } else if (!_sameAmount(ingredient.amount, ingredient.baselineAmount)) {
        changes.add(
          '${ingredient.name} '
          '${_formatAmount(ingredient.baselineAmount, ingredient.unit)} → '
          '${_formatAmount(ingredient.amount, ingredient.unit)}',
        );
      }
    }
    for (final MapEntry(key: index, value: seconds)
        in widget.timerSecondsByStep.entries) {
      if (index < 0 || index >= widget.setupSnapshot.steps.length) continue;
      final original = widget.setupSnapshot.steps[index].timerSeconds;
      if (original != seconds) {
        changes.add('${index + 1}단계 타이머 ${_secondsLabel(seconds)}');
      }
    }
    return changes;
  }

  Future<void> _save() async {
    if (_saving || _saved != null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final result = await _reviewRepository.submit(
        clientSessionId: widget.clientSessionId,
        cookedAt: widget.cookedAt,
        snapshot: widget.setupSnapshot,
        timerSecondsByStep: widget.timerSecondsByStep,
        rating: rating,
        comment: _commentController.text,
        nextTimeNote: _nextTimeController.text,
      );
      await const CookingSessionStore().clear();
      if (!mounted) return;
      setState(() {
        _saved = result;
        _saving = false;
      });
    } on ReviewApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = '후기를 저장하지 못했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final changes = _changeLabels;
    final sourceLabel =
        widget.setupSnapshot.source == CookingRecipeSource.personal
        ? '개인 버전 기반'
        : '원본 기반';
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
        InfoStrip(
          icon: Icons.summarize_rounded,
          title: '${widget.setupSnapshot.targetServings}인분 · $sourceLabel',
          body: changes.isEmpty
              ? '선택한 레시피 그대로 조리했어요. 후기는 조리 기록에 저장돼요.'
              : changes.join(' · '),
        ),
        const SectionTitle('이번 요리 메모'),
        TextField(
          controller: _commentController,
          enabled: !_saving && _saved == null,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '맛과 조리 결과를 기록해보세요.'),
        ),
        const SectionTitle('다음에는'),
        TextField(
          controller: _nextTimeController,
          enabled: !_saving && _saved == null,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '다음 조리에 기억할 점을 남겨주세요.'),
        ),
        if (changes.isNotEmpty) ...[
          const SectionTitle('자동으로 기록한 변경'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final change in changes) Pill(change)],
          ),
        ],
        if (_saveError case final String error) ...[
          const SizedBox(height: 16),
          InfoStrip(
            icon: Icons.error_outline_rounded,
            title: '저장하지 못했어요',
            body: error,
          ),
        ],
        if (_saved case final ReviewSaveResult saved) ...[
          const SizedBox(height: 16),
          InfoStrip(
            icon: Icons.check_circle_rounded,
            title: '조리 기록을 저장했어요',
            body: saved.createdPersonalVersionId == null
                ? '실행 변경이 없어 후기에만 기록했어요.'
                : '실행한 변경을 새 개인 레시피 버전으로 함께 저장했어요.',
          ),
        ],
      ],
      bottom: PressableScale(
        child: FilledButton(
          onPressed: _saving ? null : (_saved == null ? _save : _goHome),
          child: Text(
            _saving
                ? '저장 중'
                : _saved == null
                ? '조리 기록 저장'
                : '홈으로',
          ),
        ),
      ),
    );
  }
}

bool _sameAmount(double? left, double? right) {
  if (left == null || right == null) return left == right;
  return (left - right).abs() < 0.0001;
}

String _secondsLabel(int seconds) {
  if (seconds % 60 == 0) return '${seconds ~/ 60}분';
  return '${seconds ~/ 60}분 ${seconds % 60}초';
}
