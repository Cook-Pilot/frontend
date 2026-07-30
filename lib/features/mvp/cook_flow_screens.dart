import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/identity/uuid_v4.dart';
import '../cooking/application/cooking_ports.dart';
import '../cooking/application/cooking_session_store.dart';
import '../cooking/application/timer_controller.dart';
import '../cooking/data/exception_advice_api.dart';
import '../cooking/domain/cooking_setup_snapshot.dart';
import '../cooking/domain/cooking_session_state.dart';
import '../cooking/domain/cooking_voice_router.dart';
import '../cooking/presentation/cooking_voice_session_controller.dart';
import '../cooking/presentation/native_speech_input.dart';
import '../cooking/presentation/timer_alarm_provider.dart';
import '../cooking/presentation/widgets/help_question_sheet.dart';
import '../recipe/data/recipe_api.dart';
import '../recipe/domain/recipe.dart';
import '../recommendation/data/recommendation_api.dart';
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
                          builder: (_) => CookSetupScreen(
                            recipe: recipe,
                            recommendationDataSource:
                                RecommendationRepository(),
                          ),
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
    this.recommendationDataSource,
    this.sessionAlarm,
    this.sessionSpeechInput,
  });

  final Recipe recipe;
  final RecipeRepository? recipeRepository;
  final RecommendationDataSource? recommendationDataSource;
  final TimerAlarmPort? sessionAlarm;
  final SpeechInputPort? sessionSpeechInput;

  @override
  State<CookSetupScreen> createState() => _CookSetupScreenState();
}

class _CookSetupScreenState extends State<CookSetupScreen> {
  late int servings;
  late final RecipeRepository _recipeRepository;
  late final RecommendationDataSource? _recommendationDataSource;
  late List<_IngredientSetupDraft> _ingredients;
  late List<CookStep> _steps;
  List<PersonalRecipeVersionSummary> _personalVersions = const [];
  PersonalRecipeVersionDetail? _personalVersion;
  bool _loadingPersonalVersion = false;
  bool _usePersonalVersion = false;
  String? _personalVersionError;
  List<NextCookRecommendation> _recommendations = const [];
  final Set<String> _handledRecommendationIds = {};
  final Set<String> _savingRecommendationIds = {};
  final Map<String, _AppliedRecommendation> _appliedRecommendations = {};
  bool _loadingRecommendations = false;
  String? _recommendationError;
  bool _handsFreeVoiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _recipeRepository = widget.recipeRepository ?? RecipeRepository();
    _recommendationDataSource = widget.recommendationDataSource;
    servings = widget.recipe.baseServings.round().clamp(1, 99);
    _applySelectedRecipe();
    unawaited(_loadPersonalVersions());
    if (_recommendationDataSource != null) {
      unawaited(_loadRecommendations());
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecommendations = true;
      _recommendationError = null;
    });
    try {
      final result = await _recommendationDataSource!.findForRecipe(
        widget.recipe.id,
      );
      if (!mounted) return;
      setState(() {
        _recommendations = result.recommendations
            .where(
              (item) =>
                  item.type == 'INGREDIENT_AMOUNT' && item.suggestedAmount >= 0,
            )
            .toList(growable: false);
        _loadingRecommendations = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingRecommendations = false;
        _recommendationError = '추천을 불러오지 못했지만 기존 설정으로 조리할 수 있어요.';
      });
    }
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
    _ingredients = personal == null
        ? sourceIngredients
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
                  baselineUnit: ingredient.unit,
                  baselineIsRequired: ingredient.isRequired,
                  unit: ingredient.unit,
                  isRequired: ingredient.isRequired,
                ),
              )
              .toList(growable: false)
        : buildOriginalAnchoredSetupIngredients(
            baseIngredients: widget.recipe.ingredients,
            composedIngredients: personal.ingredients,
            scale: scale,
          ).map(_IngredientSetupDraft.fromSnapshot).toList(growable: false);
    _ingredients = _ingredients
        .map((ingredient) {
          final originalIngredientId = ingredient.originalIngredientId;
          final appliedRecommendation = originalIngredientId == null
              ? null
              : _appliedRecommendations[originalIngredientId];
          if (appliedRecommendation == null ||
              ingredient.omitted ||
              !_sameIngredientName(
                ingredient.name,
                appliedRecommendation.ingredientName,
              )) {
            return ingredient;
          }
          return ingredient.copyWith(
            amount: appliedRecommendation.amount * scale,
          );
        })
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
      baseServings: _safeBaseServings,
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
    final visibleRecommendations = _recommendations
        .where(
          (item) => !_handledRecommendationIds.contains(item.recommendationId),
        )
        .toList(growable: false);

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
        if (_recommendationDataSource != null) ...[
          const SectionTitle('내 기록에서 찾은 추천'),
          if (_loadingRecommendations)
            const InfoStrip(
              icon: Icons.auto_awesome_rounded,
              title: '내 조리 기록을 확인하고 있어요',
              body: '반복해서 만족했던 변경만 골라볼게요.',
            )
          else if (_recommendationError != null)
            InfoStrip(
              icon: Icons.info_outline_rounded,
              title: '추천 없이 진행해요',
              body: _recommendationError!,
            )
          else if (_recommendations.isEmpty)
            const InfoStrip(
              icon: Icons.history_rounded,
              title: '아직 확실한 추천이 없어요',
              body: '비슷한 요리를 만족스럽게 두 번 이상 기록하면 변경안을 제안해요.',
            )
          else if (visibleRecommendations.isEmpty)
            const InfoStrip(
              icon: Icons.check_circle_outline_rounded,
              title: '추천 선택을 반영했어요',
              body: '최종 재료 설정을 확인한 뒤 조리를 시작해주세요.',
            )
          else
            for (final recommendation in visibleRecommendations)
              _buildRecommendationCard(context, recommendation),
        ],
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
        const SectionTitle('조리 중 음성 사용'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('cooking-voice-mode-manual'),
              label: const Text('버튼으로 사용'),
              selected: !_handsFreeVoiceEnabled,
              onSelected: setupLocked
                  ? null
                  : (_) => setState(() => _handsFreeVoiceEnabled = false),
            ),
            ChoiceChip(
              key: const Key('cooking-voice-mode-hands-free'),
              label: const Text('핸즈프리 음성'),
              selected: _handsFreeVoiceEnabled,
              onSelected: setupLocked
                  ? null
                  : (_) => setState(() => _handsFreeVoiceEnabled = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoStrip(
          key: const Key('cooking-voice-mode-description'),
          icon: _handsFreeVoiceEnabled
              ? Icons.record_voice_over_rounded
              : Icons.mic_none_rounded,
          title: _handsFreeVoiceEnabled
              ? '조리 시작과 함께 음성을 들어요'
              : '마이크는 자동으로 켜지지 않아요',
          body: _handsFreeVoiceEnabled
              ? '명령을 처리한 뒤 다시 듣습니다. 직접 입력을 열거나 앱을 벗어나면 자동 듣기를 멈춰요.'
              : '기본 설정이에요. 조리 중 말하기 버튼을 누른 경우에만 음성을 사용합니다.',
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
                        recipe: snapshot.toExecutionRecipe(),
                        servings: servings,
                        setupSnapshot: snapshot,
                        alarm: widget.sessionAlarm,
                        advicePort: HttpExceptionAdvicePort(),
                        speechInput: widget.sessionSpeechInput,
                        handsFreeVoiceEnabled: _handsFreeVoiceEnabled,
                      ),
                    ),
                  );
                },
          child: Text(setupLocked ? '나 맞춤 버전 불러오는 중' : '이 설정으로 조리 시작'),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    NextCookRecommendation recommendation,
  ) {
    final scale = servings / _safeBaseServings;
    final originalLabel = _formatAmount(
      recommendation.originalAmount * scale,
      recommendation.unit,
    );
    final suggestedLabel = _formatAmount(
      recommendation.suggestedAmount * scale,
      recommendation.unit,
    );
    final saving = _savingRecommendationIds.contains(
      recommendation.recommendationId,
    );
    final percent = recommendation.changePercent.abs();
    final direction = recommendation.changePercent < 0 ? '감소' : '증가';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${recommendation.ingredientName} $percent% $direction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$originalLabel → $suggestedLabel',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.reason,
              style: const TextStyle(color: AppColors.slate, height: 1.45),
            ),
            const SizedBox(height: 6),
            Text(
              '근거 ${recommendation.evidence.length}회',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => unawaited(_rejectRecommendation(recommendation)),
                  child: const Text('사용 안 함'),
                ),
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => unawaited(
                          _modifyRecommendation(context, recommendation),
                        ),
                  child: const Text('수정'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () => unawaited(
                          _applyRecommendation(
                            recommendation,
                            recommendation.suggestedAmount * scale,
                            RecommendationDecision.accepted,
                          ),
                        ),
                  child: Text(saving ? '저장 중' : '이번 조리에 적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectRecommendation(
    NextCookRecommendation recommendation,
  ) async {
    if (_savingRecommendationIds.contains(recommendation.recommendationId)) {
      return;
    }
    setState(() {
      _savingRecommendationIds.add(recommendation.recommendationId);
      _handledRecommendationIds.add(recommendation.recommendationId);
    });
    try {
      await _recommendationDataSource!.recordFeedback(
        recipeId: widget.recipe.id,
        recommendation: recommendation,
        decision: RecommendationDecision.rejected,
      );
    } on Object {
      _showRecommendationFeedbackWarning();
    } finally {
      if (mounted) {
        setState(
          () =>
              _savingRecommendationIds.remove(recommendation.recommendationId),
        );
      }
    }
  }

  Future<void> _applyRecommendation(
    NextCookRecommendation recommendation,
    double appliedAmount,
    RecommendationDecision decision,
  ) async {
    if (_savingRecommendationIds.contains(recommendation.recommendationId)) {
      return;
    }
    final ingredientIndex = _ingredients.indexWhere(
      (item) =>
          item.originalIngredientId == recommendation.originalIngredientId,
    );
    if (ingredientIndex < 0) {
      _showRecommendationMessage('현재 재료 목록에서 추천 대상을 찾지 못했어요.');
      return;
    }
    final ingredient = _ingredients[ingredientIndex];
    if (ingredient.omitted ||
        !_sameIngredientName(ingredient.name, recommendation.ingredientName)) {
      _showRecommendationMessage('이 재료가 생략되거나 대체되어 있어 기본 재료로 되돌린 뒤 적용해주세요.');
      return;
    }

    final scale = servings / _safeBaseServings;
    final normalizedAppliedAmount = appliedAmount / scale;
    setState(() {
      _ingredients[ingredientIndex] = ingredient.copyWith(
        amount: appliedAmount,
        omitted: false,
      );
      _appliedRecommendations[recommendation.originalIngredientId] =
          _AppliedRecommendation(
            ingredientName: recommendation.ingredientName,
            amount: normalizedAppliedAmount,
          );
      _savingRecommendationIds.add(recommendation.recommendationId);
      _handledRecommendationIds.add(recommendation.recommendationId);
    });
    try {
      await _recommendationDataSource!.recordFeedback(
        recipeId: widget.recipe.id,
        recommendation: recommendation,
        decision: decision,
        appliedAmount: normalizedAppliedAmount,
      );
    } on Object {
      _showRecommendationFeedbackWarning();
    } finally {
      if (mounted) {
        setState(
          () =>
              _savingRecommendationIds.remove(recommendation.recommendationId),
        );
      }
    }
  }

  Future<void> _modifyRecommendation(
    BuildContext context,
    NextCookRecommendation recommendation,
  ) async {
    final scale = servings / _safeBaseServings;
    var amount = recommendation.suggestedAmount * scale;
    final selectedAmount = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recommendation.ingredientName} 추천 수정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation.reason,
                    style: const TextStyle(color: AppColors.slate, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: amount <= 0
                            ? null
                            : () => setSheetState(
                                () => amount = _adjustAmount(
                                  amount,
                                  recommendation.unit,
                                  -1,
                                ),
                              ),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Text(
                          _formatAmount(amount, recommendation.unit),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () => setSheetState(
                          () => amount = _adjustAmount(
                            amount,
                            recommendation.unit,
                            1,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(amount),
                      child: const Text('수정한 양으로 적용'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted || selectedAmount == null) return;
    await _applyRecommendation(
      recommendation,
      selectedAmount,
      RecommendationDecision.modified,
    );
  }

  void _showRecommendationFeedbackWarning() {
    _showRecommendationMessage('설정은 반영했지만 추천 선택 기록은 저장하지 못했어요.');
  }

  void _showRecommendationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      final originalIngredientId = ingredient.originalIngredientId;
      if (originalIngredientId != null) {
        _appliedRecommendations.remove(originalIngredientId);
      }
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
          amount: ingredient.baselineAmount,
          unit: ingredient.baselineUnit,
          isRequired: ingredient.baselineIsRequired,
          omitted: false,
        ),
      };
    });
  }
}

enum _IngredientEditMode { amount, substitute, omit, restoreOriginal }

final class _AppliedRecommendation {
  const _AppliedRecommendation({
    required this.ingredientName,
    required this.amount,
  });

  final String ingredientName;
  final double amount;
}

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
    required this.baselineUnit,
    required this.baselineIsRequired,
    required this.unit,
    required this.isRequired,
    this.omitted = false,
  });

  factory _IngredientSetupDraft.fromSnapshot(
    CookingSetupIngredient ingredient,
  ) {
    return _IngredientSetupDraft(
      originalIngredientId: ingredient.originalIngredientId,
      originalName: ingredient.originalName,
      name: ingredient.name,
      amount: ingredient.amount,
      baselineAmount: ingredient.baselineAmount,
      baselineUnit: ingredient.baselineUnit ?? ingredient.unit,
      baselineIsRequired:
          ingredient.baselineIsRequired ?? ingredient.isRequired,
      unit: ingredient.unit,
      isRequired: ingredient.isRequired,
      omitted: ingredient.omitted,
    );
  }

  static const _unset = Object();

  final String? originalIngredientId;
  final String originalName;
  final String name;
  final double? amount;
  final double? baselineAmount;
  final String baselineUnit;
  final bool baselineIsRequired;
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
    baselineUnit: baselineUnit,
    baselineIsRequired: baselineIsRequired,
    unit: unit,
    isRequired: isRequired,
    omitted: omitted,
  );

  _IngredientSetupDraft copyWith({
    String? name,
    Object? amount = _unset,
    String? unit,
    bool? isRequired,
    bool? omitted,
  }) {
    return _IngredientSetupDraft(
      originalIngredientId: originalIngredientId,
      originalName: originalName,
      name: name ?? this.name,
      amount: identical(amount, _unset) ? this.amount : amount as double?,
      baselineAmount: baselineAmount,
      baselineUnit: baselineUnit,
      baselineIsRequired: baselineIsRequired,
      unit: unit ?? this.unit,
      isRequired: isRequired ?? this.isRequired,
      omitted: omitted ?? this.omitted,
    );
  }

  CookingSetupIngredient toSnapshot() => CookingSetupIngredient(
    originalIngredientId: originalIngredientId,
    originalName: originalName,
    name: name,
    amount: amount,
    baselineAmount: baselineAmount,
    baselineUnit: baselineUnit,
    baselineIsRequired: baselineIsRequired,
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

bool _sameIngredientName(String left, String right) {
  String normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return normalize(left) == normalize(right);
}

typedef _CookSpeechPhase = CookingVoiceSpeechPhase;

class CookSessionScreen extends StatefulWidget {
  const CookSessionScreen({
    super.key,
    required this.recipe,
    required this.servings,
    this.setupSnapshot,
    this.restoredSession,
    this.alarm,
    this.alarmResolver,
    this.advicePort,
    this.speechInput,
    this.handsFreeVoiceEnabled = false,
  });

  final Recipe recipe;
  final int servings;
  final CookingSetupSnapshot? setupSnapshot;

  /// 홈의 "이어서 조리하기"로 진입할 때 전달되는 저장 세션.
  final PersistedCookingSession? restoredSession;

  /// 테스트에서 플랫폼 알림 초기화를 대체하기 위한 주입 지점.
  final TimerAlarmPort? alarm;

  /// 권한 요청을 포함한 비동기 알림 초기화의 테스트 주입 지점.
  final Future<TimerAlarmPort> Function()? alarmResolver;

  /// 테스트에서는 fake를 주입하고, 실제 앱에서는 백엔드 F-08 API를 사용한다.
  final ExceptionAdvicePort? advicePort;

  /// 테스트에서는 fake를, 실제 앱에서는 네이티브 STT 구현을 사용한다.
  final SpeechInputPort? speechInput;

  /// 조리 설정에서 사용자가 명시적으로 핸즈프리를 선택한 경우에만 true다.
  ///
  /// false이면 마이크를 자동으로 열지 않고 기존 말하기 버튼으로만 시작한다.
  final bool handsFreeVoiceEnabled;

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
      widget.advicePort ?? HttpExceptionAdvicePort();
  late final CookingVoiceSessionController _voiceSession;
  static const CookingVoiceRouter _voiceRouter = CookingVoiceRouter();
  String? _helpAnswer;
  ExceptionAdviceSuggestedAction? _helpSuggestedAction;
  bool _helpLoading = false;
  int _helpRequestVersion = 0;
  int? _helpRequestOwnerVersion;

  bool get _helpRequestInFlight =>
      _helpRequestOwnerVersion == _helpRequestVersion;

  String? _voiceMessage;
  bool _disposed = false;

  // 원래 디자인은 그대로 두고 시계(타이머)만 실제로 동작시킨다.
  // 기본 클럭이 WallAnchoredMonotonicClock이라 화면이 꺼져도 시간이 이어진다.
  final LocalTimerController _timer = LocalTimerController();
  TimerAlarmPort? _alarm;
  late final Future<void> _alarmInitialization;
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
  bool _closingSession = false;
  bool _allowSessionPop = false;

  @override
  void initState() {
    super.initState();
    _voiceSession = CookingVoiceSessionController(
      speechInput: widget.speechInput ?? NativeSpeechInput(),
      handsFreeEnabled: widget.handsFreeVoiceEnabled,
      initialLifecycleState:
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      onStateChanged: _onSpeechStateChanged,
      onTranscript: _handleSpeechUtterance,
    );
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
    _alarmInitialization = _initAlarm();
    unawaited(_alarmInitialization);
    _persist();
    if (_voiceSession.shouldAutoStartHandsFree) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Notification and microphone permissions both drive app lifecycle
        // transitions. Serialize them so two system dialogs cannot race.
        await _alarmInitialization;
        if (_voiceSession.shouldAutoStartHandsFree && mounted) {
          await _voiceSession.startHandsFree();
        }
      });
    }
  }

  Future<void> _initAlarm() async {
    // 백그라운드 알림용 로컬 알림을 한 번 초기화(권한 요청 포함)한다.
    try {
      final TimerAlarmPort alarm;
      if (widget.alarm case final injected?) {
        alarm = injected;
      } else if (widget.alarmResolver case final resolver?) {
        alarm = await resolver();
      } else {
        alarm = await resolveTimerAlarm();
      }
      if (mounted) {
        _alarm = alarm;
        // 복원된 타이머가 이미 실행 중이면 종료 알림을 다시 예약한다.
        _scheduleAlarm();
      }
    } catch (_) {
      // 알림 권한이나 플러그인 초기화가 실패해도 화면 타이머와 음성 조리는
      // 계속 사용할 수 있다.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 화면을 다시 켜면 잠든 사이 흐른 시간을 반영해 남은 시간을 재계산한다.
    if (state == AppLifecycleState.resumed) {
      _timer.sync();
    }
    _voiceSession.handleLifecycleStateChanged(state);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer.removeListener(_onTimerChanged);
    _voiceSession.dispose();
    unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
    _timer.dispose();
    super.dispose();
  }

  _CookSpeechPhase get _speechPhase => _voiceSession.phase;

  bool get _speechIsActive => _voiceSession.isActive;

  Future<void> _deactivateSpeechInput({
    bool forceStop = false,
    String? message,
    bool rearmHandsFree = false,
  }) => rearmHandsFree
      ? _voiceSession.deactivateAndRearmHandsFree(message: message)
      : _voiceSession.deactivate(forceStop: forceStop, message: message);

  void _toggleSpeechInput() => _voiceSession.toggle();

  void _onSpeechStateChanged(_CookSpeechPhase _, String? message) {
    if (_disposed || !mounted) {
      return;
    }
    setState(() {
      if (message != null) {
        _voiceMessage = message;
      }
    });
  }

  void _handleSpeechUtterance(String transcript) {
    final intent = _voiceRouter.route(
      transcript,
      recipeTitle: widget.recipe.title,
      ingredientNames: [
        for (final ingredient in widget.recipe.ingredients) ingredient.name,
      ],
      currentStepInstruction: widget.recipe.steps[step - 1].instruction,
    );
    _applyVoiceIntent(intent, transcript: transcript);
  }

  void _applyVoiceIntent(VoiceIntent intent, {required String transcript}) {
    if (_disposed || _completed || !mounted) {
      return;
    }
    switch (intent.type) {
      case VoiceIntentType.next:
        _moveCookingStep(1, fromVoice: true);
      case VoiceIntentType.previous:
        _moveCookingStep(-1, fromVoice: true);
      case VoiceIntentType.repeat:
        _setVoiceMessage(
          '현재 안내를 다시 보여드릴게요. '
          '${widget.recipe.steps[step - 1].description}',
        );
      case VoiceIntentType.currentStep:
        _setVoiceMessage(
          '현재는 $step단계예요. '
          '${widget.recipe.steps[step - 1].description}',
        );
      case VoiceIntentType.startTimer:
        _startTimerFromVoice();
      case VoiceIntentType.extendTimer:
        _extendTimerFromVoice(intent.seconds);
      case VoiceIntentType.pauseTimer:
        _pauseTimerFromVoice();
      case VoiceIntentType.resumeTimer:
        _resumeTimerFromVoice();
      case VoiceIntentType.finish:
        _finishCooking();
      case VoiceIntentType.exceptionQuestion:
        unawaited(_requestAdvice(transcript));
      case VoiceIntentType.ignore:
        _setVoiceMessage('명령을 이해하지 못했어요. 다시 말하거나 직접 입력을 이용해주세요.');
    }
  }

  void _setVoiceMessage(String message) {
    if (_disposed || _completed || !mounted) {
      return;
    }
    setState(() => _voiceMessage = message);
  }

  void _moveCookingStep(int delta, {required bool fromVoice}) {
    if (_completed) {
      return;
    }
    final target = step + delta;
    if (target < 1) {
      _setVoiceMessage('첫 단계예요. 이전 단계가 없어요.');
      return;
    }
    if (target > widget.recipe.steps.length) {
      _setVoiceMessage('마지막 단계예요. 완료했다면 “조리 완료”라고 말해주세요.');
      return;
    }
    // 화면 버튼으로 이동할 때도 진행 중인 음성 세션을 끊어, 이전 단계에서
    // 시작된 인식 결과가 새 단계에 적용되지 않도록 한다.
    if (_speechIsActive) {
      unawaited(_deactivateSpeechInput(rearmHandsFree: true));
    }
    _helpRequestVersion++;
    setState(() {
      step = target;
      _helpAnswer = null;
      _helpSuggestedAction = null;
      _helpLoading = false;
      _voiceMessage = fromVoice ? '$target단계로 이동했어요.' : null;
    });
    _resetTimerForStep(keepRecordedDuration: true);
    _persist();
  }

  bool get _currentStepHasTimer =>
      widget.recipe.steps[step - 1].timerDuration > Duration.zero;

  void _startTimerFromVoice() {
    if (!_currentStepHasTimer) {
      _setVoiceMessage('현재 단계에는 설정된 타이머가 없어요.');
      return;
    }
    _timer.sync();
    switch (_timer.status) {
      case TimerStatus.idle:
        _timer.start();
        _scheduleAlarm();
        _setVoiceMessage('타이머를 시작했어요.');
      case TimerStatus.paused:
        _timer.resume();
        _scheduleAlarm();
        _setVoiceMessage('일시정지한 타이머를 다시 시작했어요.');
      case TimerStatus.running:
        _setVoiceMessage('타이머가 이미 실행 중이에요.');
      case TimerStatus.elapsed:
        _setVoiceMessage('타이머가 이미 끝났어요. 시간을 추가하거나 리셋해주세요.');
    }
  }

  void _extendTimerFromVoice(int requestedSeconds) {
    if (!_currentStepHasTimer) {
      _setVoiceMessage('현재 단계에는 연장할 타이머가 없어요.');
      return;
    }
    final seconds = requestedSeconds > 0 ? requestedSeconds : 60;
    final extension = Duration(seconds: seconds);
    _extendCurrentTimer(extension);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    final amount = switch ((minutes, remainder)) {
      (> 0, 0) => '$minutes분',
      (0, > 0) => '$remainder초',
      _ => '$minutes분 $remainder초',
    };
    final objectParticle = remainder == 0 ? '을' : '를';
    _setVoiceMessage('타이머에 $amount$objectParticle 추가했어요.');
  }

  void _pauseTimerFromVoice() {
    if (!_currentStepHasTimer) {
      _setVoiceMessage('현재 단계에는 일시정지할 타이머가 없어요.');
      return;
    }
    _timer.sync();
    if (_timer.status != TimerStatus.running) {
      _setVoiceMessage(
        _timer.status == TimerStatus.elapsed
            ? '타이머가 이미 끝났어요.'
            : '현재 실행 중인 타이머가 없어요.',
      );
      return;
    }
    _timer.pause();
    unawaited(_alarm?.cancelScheduledAlarm() ?? Future<void>.value());
    _setVoiceMessage('타이머를 일시정지했어요.');
  }

  void _resumeTimerFromVoice() {
    if (!_currentStepHasTimer) {
      _setVoiceMessage('현재 단계에는 다시 시작할 타이머가 없어요.');
      return;
    }
    if (_timer.status != TimerStatus.paused) {
      _setVoiceMessage('일시정지된 타이머가 없어요.');
      return;
    }
    _timer.resume();
    _scheduleAlarm();
    _setVoiceMessage('타이머를 다시 시작했어요.');
  }

  void _finishCooking() {
    if (_completed || !mounted) {
      return;
    }
    _completed = true;
    _helpRequestVersion++;
    _voiceSession.complete();
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
  }

  void _closeCookingSession() {
    if (!mounted || _closingSession) {
      return;
    }
    _closingSession = true;
    // Invalidate callbacks and begin closing the microphone before the route
    // transition reveals the previous screen.
    _voiceSession.complete();
    setState(() => _allowSessionPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
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

  void _resetTimerForStep({bool keepRecordedDuration = false}) {
    final recordedSeconds = keepRecordedDuration
        ? _timerSecondsByStep[step - 1]
        : null;
    if (!keepRecordedDuration) {
      _timerSecondsByStep.remove(step - 1);
    }
    final duration = recordedSeconds == null
        ? widget.recipe.steps[step - 1].timerDuration
        : Duration(seconds: recordedSeconds);
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
    _extendCurrentTimer(const Duration(minutes: 1));
  }

  void _extendCurrentTimer(Duration extension) {
    _timerSecondsByStep[step - 1] =
        _timer.effectiveDuration.inSeconds + extension.inSeconds;
    _timer.add(extension);
    _scheduleAlarm();
  }

  Future<void> _openHelpSheet() async {
    _voiceSession.disableAutomaticRearm();
    if (_speechIsActive) {
      unawaited(_deactivateSpeechInput(message: '음성 입력을 멈췄어요. 질문을 직접 입력해주세요.'));
    }
    final question = await HelpQuestionSheet.show(context);
    if (question == null || !mounted) {
      return;
    }
    await _requestAdvice(question);
  }

  Future<void> _requestAdvice(String question) async {
    final normalizedQuestion = question.trim();
    if (_disposed ||
        _completed ||
        !mounted ||
        _helpRequestInFlight ||
        normalizedQuestion.isEmpty) {
      return;
    }
    if (normalizedQuestion.length > maxExceptionAdviceQuestionLength) {
      setState(() {
        _helpLoading = false;
        _helpAnswer = '질문은 $maxExceptionAdviceQuestionLength자 이하로 줄여주세요.';
        _helpSuggestedAction = null;
      });
      return;
    }
    final requestVersion = ++_helpRequestVersion;
    final requestedStep = step;
    _helpRequestOwnerVersion = requestVersion;
    setState(() {
      _helpLoading = true;
      _helpAnswer = null;
      _helpSuggestedAction = null;
    });
    ExceptionAdvice advice;
    try {
      advice = await _advice.requestAdvice(
        ExceptionAdviceContext(
          sessionId: _sessionId,
          recipeId: widget.recipe.id,
          recipeVersionId: 'mvp',
          stepIndex: requestedStep - 1,
          requestContextVersion: requestVersion,
          // 개인 버전의 현재 실행 단계 문장뿐 아니라 주의사항까지 함께 보낸다.
          // 서버의 원본 stepIndex는 ADD/REMOVE로 재인덱싱된 실행 스냅샷과
          // 다를 수 있으므로 이 description이 F8 현재 단계 문맥의 정본이다.
          instruction: widget.recipe.steps[requestedStep - 1].description,
          remaining: _timer.remaining,
          utterance: normalizedQuestion,
          recentEvents: const [],
        ),
      );
    } catch (_) {
      if (!_ownsCurrentHelpRequest(requestVersion, requestedStep)) {
        _releaseHelpRequest(requestVersion);
        return;
      }
      setState(() {
        _helpRequestOwnerVersion = null;
        _helpLoading = false;
        _helpAnswer = '답변을 불러오지 못했어요. 버튼과 타이머는 계속 사용할 수 있어요.';
        _helpSuggestedAction = null;
      });
      return;
    }
    // 기다리는 사이 단계가 바뀌었거나 새 요청이 시작됐으면 낡은 답변을
    // 표시하지 않고 새 요청의 진행 상태도 건드리지 않는다.
    if (!_ownsCurrentHelpRequest(requestVersion, requestedStep)) {
      _releaseHelpRequest(requestVersion);
      return;
    }
    setState(() {
      _helpRequestOwnerVersion = null;
      _helpLoading = false;
      _helpAnswer = advice.message;
      _helpSuggestedAction = advice.isMock
          ? null
          : _safeSuggestedAction(advice.suggestedAction);
    });
  }

  bool _ownsCurrentHelpRequest(int requestVersion, int requestedStep) =>
      mounted &&
      !_disposed &&
      !_completed &&
      _helpRequestOwnerVersion == requestVersion &&
      _helpRequestVersion == requestVersion &&
      step == requestedStep;

  void _releaseHelpRequest(int requestVersion) {
    if (_helpRequestOwnerVersion == requestVersion) {
      _helpRequestOwnerVersion = null;
    }
  }

  ExceptionAdviceSuggestedAction? _safeSuggestedAction(
    ExceptionAdviceSuggestedAction? action,
  ) {
    if (action == null ||
        !_currentStepHasTimer ||
        action.type != ExceptionAdviceActionType.extendTimer ||
        (action.seconds != 30 && action.seconds != 60)) {
      return null;
    }
    return action;
  }

  void _applySuggestedAction() {
    final action = _helpSuggestedAction;
    if (action == null || _disposed || _completed || !mounted) {
      return;
    }
    setState(() => _helpSuggestedAction = null);
    switch (action.type) {
      case ExceptionAdviceActionType.extendTimer:
        // API 파서가 30/60초만 통과시키지만 화면 경계에서도 한 번 더 막는다.
        if (action.seconds != 30 && action.seconds != 60) {
          return;
        }
        _extendCurrentTimer(Duration(seconds: action.seconds));
        _setVoiceMessage(
          action.seconds == 60 ? '타이머에 1분을 추가했어요.' : '타이머에 30초를 추가했어요.',
        );
    }
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

  String get _speechTitle => switch (_speechPhase) {
    _CookSpeechPhase.idle => '음성으로 조리하기',
    _CookSpeechPhase.starting => '마이크 준비 중',
    _CookSpeechPhase.listening => '듣는 중',
    _CookSpeechPhase.stopping => '마이크 정리 중',
    _CookSpeechPhase.permissionDenied => '마이크 권한 필요',
    _CookSpeechPhase.retryRequired => '다시 말해주세요',
    _CookSpeechPhase.unavailable => '음성 입력 사용 불가',
  };

  String get _speechBody =>
      _voiceMessage ?? '단계 이동, 현재 안내, 타이머 조작을 말로 할 수 있어요.';

  String get _speechButtonLabel => switch (_speechPhase) {
    _CookSpeechPhase.starting || _CookSpeechPhase.listening => '듣기 중지',
    _CookSpeechPhase.stopping => '중지 중',
    _CookSpeechPhase.permissionDenied => '권한 다시 확인',
    _CookSpeechPhase.retryRequired => '다시 말하기',
    _CookSpeechPhase.unavailable => '다시 시도',
    _CookSpeechPhase.idle => '말하기',
  };

  IconData get _speechIcon => switch (_speechPhase) {
    _CookSpeechPhase.listening => Icons.graphic_eq_rounded,
    _CookSpeechPhase.permissionDenied => Icons.mic_off_rounded,
    _CookSpeechPhase.unavailable => Icons.error_outline_rounded,
    _ => Icons.mic_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final current = widget.recipe.steps[step - 1];
    final isLast = step == widget.recipe.steps.length;
    final hasTimer = current.timerDuration > Duration.zero;

    final screen = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _closeCookingSession,
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
            InfoStrip(
              key: const Key('voice-input-status'),
              icon: _speechIcon,
              title: _speechTitle,
              body: _speechBody,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('voice-input-toggle'),
                    onPressed: _speechPhase == _CookSpeechPhase.stopping
                        ? null
                        : _toggleSpeechInput,
                    icon: Icon(
                      _speechPhase == _CookSpeechPhase.starting ||
                              _speechPhase == _CookSpeechPhase.listening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      size: 20,
                    ),
                    label: Text(_speechButtonLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('help-request'),
                    onPressed: _helpRequestInFlight ? null : _openHelpSheet,
                    icon: const Icon(Icons.keyboard_rounded, size: 20),
                    label: const Text('직접 입력'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'AI 질문은 답변 생성을 위해 Google Gemini로 전송될 수 있어요. '
              '개인정보·건강정보는 말하거나 입력하지 마세요.',
              key: const Key('ai-data-disclosure'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              if (_helpSuggestedAction
                  case final ExceptionAdviceSuggestedAction action) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('help-suggested-action'),
                  onPressed: _applySuggestedAction,
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(
                    '제안 적용 · '
                    '${action.seconds == 60 ? '1분' : '${action.seconds}초'} 추가',
                  ),
                ),
              ],
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
                _finishCooking();
              } else {
                _moveCookingStep(1, fromVoice: false);
              }
            },
            child: Text(isLast ? '조리 완료' : '다음 단계'),
          ),
        ),
      ),
    );
    return PopScope(
      canPop: _allowSessionPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeCookingSession();
        }
      },
      child: screen,
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
      baseServings: widget.recipe.baseServings > 0
          ? widget.recipe.baseServings
          : 1,
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
            baselineUnit: ingredient.unit,
            baselineIsRequired: ingredient.isRequired,
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
