import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../cooking/application/cooking_session_store.dart';
import '../recipe/data/recipe_api.dart';
import '../recipe/domain/recipe.dart';
import 'cook_flow_screens.dart';
import 'mvp_widgets.dart';

final _recipeRepository = RecipeRepository();

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [HomeScreen(), SearchScreen(), MemoryScreen()];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: '검색',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: '메모리',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CookingSessionStore _sessionStore = const CookingSessionStore();

  late Future<_HomeCatalog> _catalog;
  PersistedCookingSession? _resumableSession;
  Recipe? _resumableRecipe;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
    unawaited(_loadResumableSession());
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return '좋은 아침이에요';
    if (hour < 17) return '점심은 챙기셨나요?';
    return '오늘 저녁, 뭐 해먹을까요?';
  }

  Future<_HomeCatalog> _loadCatalog() async {
    final results = await Future.wait<List<RecipeSummary>>([
      _recipeRepository.findAll(),
      _recipeRepository.findRecent(),
      _recipeRepository.findFavorites(),
    ]);
    final summaries = results[0];
    final recent = results[1];
    final favorites = results[2];
    if (summaries.isEmpty) {
      return _HomeCatalog(
        summaries: summaries,
        featured: null,
        recent: recent,
        favorites: favorites,
      );
    }
    Recipe? featured;
    try {
      featured = await _recipeRepository.findById(summaries.first);
    } on Object {
      // 추천 상세가 실패해도 조회 가능한 전체 목록은 유지한다.
      featured = null;
    }
    return _HomeCatalog(
      summaries: summaries,
      featured: featured,
      recent: recent,
      favorites: favorites,
    );
  }

  void _retry() {
    setState(() => _catalog = _loadCatalog());
    unawaited(_loadResumableSession());
  }

  void _refreshHome() {
    _retry();
    unawaited(_loadResumableSession());
  }

  Future<void> _loadResumableSession() async {
    final session = await _sessionStore.load();
    if (!mounted) {
      return;
    }
    if (session == null || !session.isResumable) {
      setState(() {
        _resumableSession = null;
        _resumableRecipe = null;
      });
      return;
    }

    final storedRecipeId = session.recipeId;
    try {
      var restoredSession = session;
      final Recipe recipe;
      final recipeId = storedRecipeId;
      if (recipeId != null && recipeId.isNotEmpty) {
        recipe = await _recipeRepository.findByRecipeId(recipeId);
      } else {
        final summaries = await _recipeRepository.findAll();
        final matches = summaries
            .where((summary) => summary.title == session.recipeTitle)
            .toList(growable: false);
        if (matches.length != 1) {
          if (matches.isEmpty) {
            await _sessionStore.clear();
          }
          if (mounted) {
            setState(() {
              _resumableSession = null;
              _resumableRecipe = null;
            });
          }
          return;
        }
        recipe = await _recipeRepository.findById(matches.single);
      }
      if (recipe.steps.isEmpty) {
        await _sessionStore.clear();
        if (mounted) {
          setState(() {
            _resumableSession = null;
            _resumableRecipe = null;
          });
        }
        return;
      }
      if (session.recipeId != recipe.id ||
          session.recipeTitle != recipe.title) {
        restoredSession = session.copyWith(
          recipeId: recipe.id,
          recipeTitle: recipe.title,
        );
        await _sessionStore.save(restoredSession);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _resumableSession = restoredSession;
        _resumableRecipe = recipe;
      });
    } on RecipeApiException catch (error) {
      if (storedRecipeId == null ||
          storedRecipeId.isEmpty ||
          error.statusCode != 404) {
        return;
      }
      await _sessionStore.clear();
      if (mounted) {
        setState(() {
          _resumableSession = null;
          _resumableRecipe = null;
        });
      }
    } on Object {
      // 서버가 잠시 불안정할 때는 복원 가능한 로컬 세션을 삭제하지 않는다.
    }
  }

  Future<void> _resumeCooking() async {
    final session = _resumableSession;
    final recipe = _resumableRecipe;
    if (session == null || recipe == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CookSessionScreen(
          recipe: recipe,
          servings: session.servings,
          restoredSession: session,
        ),
      ),
    );
    if (mounted) {
      unawaited(_loadResumableSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final next = _loadCatalog();
            setState(() => _catalog = next);
            await next;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '셰프님 👋',
                          style: TextStyle(
                            color: AppColors.slate,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                  PressableScale(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (_resumableSession
                  case final PersistedCookingSession session) ...[
                const SizedBox(height: 18),
                _ResumeCookingCard(
                  session: session,
                  stepCount:
                      _resumableRecipe?.steps.length ?? session.stepIndex + 1,
                  onTap: () => unawaited(_resumeCooking()),
                ),
              ],
              FutureBuilder<_HomeCatalog>(
                future: _catalog,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _RecipeLoading();
                  }
                  if (snapshot.hasError) {
                    return _RecipeLoadError(onRetry: _retry);
                  }

                  final catalog = snapshot.data;
                  if (catalog == null || catalog.summaries.isEmpty) {
                    return const _RecipeEmpty(message: '등록된 레시피가 아직 없어요.');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (catalog.featured != null) ...[
                        const SectionTitle('오늘의 메뉴'),
                        RecipeHeroCard(
                          recipe: catalog.featured!,
                          onTap: () => Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) => RecipeDetailScreen(
                                    recipe: catalog.featured!,
                                  ),
                                ),
                              )
                              .then((_) => _refreshHome()),
                        ),
                      ],
                      const SectionTitle('최근 조리'),
                      if (catalog.recent.isEmpty)
                        const _HomeDataEmpty(
                          icon: Icons.history_rounded,
                          title: '아직 최근 조리 데이터가 없어요',
                          body: '첫 요리를 마치고 후기를 남기면 여기에 표시돼요.',
                        )
                      else
                        for (final recipe in catalog.recent.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecipeSummaryTile(
                              summary: recipe,
                              onChanged: _refreshHome,
                            ),
                          ),
                      const SectionTitle('즐겨찾기'),
                      if (catalog.favorites.isEmpty)
                        const _HomeDataEmpty(
                          icon: Icons.bookmark_outline_rounded,
                          title: '아직 즐겨찾기 데이터가 없어요',
                          body: '마음에 드는 레시피를 저장하면 바로 모아볼 수 있어요.',
                        )
                      else
                        for (final recipe in catalog.favorites.take(3))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecipeSummaryTile(
                              summary: recipe,
                              onChanged: _refreshHome,
                            ),
                          ),
                      SectionTitle('전체 레시피 ${catalog.summaries.length}'),
                      for (final recipe in catalog.summaries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecipeSummaryTile(
                            summary: recipe,
                            onChanged: _refreshHome,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late Future<List<RecipeSummary>> _recipes;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _recipes = _recipeRepository.findAll();
  }

  void _retry() {
    setState(() => _recipes = _recipeRepository.findAll());
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '검색',
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            hintText: '레시피 이름 또는 설명 검색',
          ),
        ),
        FutureBuilder<List<RecipeSummary>>(
          future: _recipes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _RecipeLoading();
            }
            if (snapshot.hasError) {
              return _RecipeLoadError(onRetry: _retry);
            }

            final query = _query.toLowerCase();
            final items = (snapshot.data ?? const <RecipeSummary>[])
                .where(
                  (recipe) =>
                      query.isEmpty ||
                      recipe.title.toLowerCase().contains(query) ||
                      recipe.description.toLowerCase().contains(query),
                )
                .toList(growable: false);

            if (items.isEmpty) {
              return const _RecipeEmpty(message: '조건에 맞는 레시피가 없어요.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('검색 결과 ${items.length}'),
                for (final recipe in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecipeSummaryTile(
                      summary: recipe,
                      onChanged: _retry,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late Future<List<RecipeSummary>> _recipes;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _recipes = _recipeRepository.findAll();
  }

  void _retry() {
    setState(() => _recipes = _recipeRepository.findAll());
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '레시피 메모리',
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            hintText: '저장한 레시피 검색',
          ),
        ),
        FutureBuilder<List<RecipeSummary>>(
          future: _recipes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _RecipeLoading();
            }
            if (snapshot.hasError) {
              return _RecipeLoadError(onRetry: _retry);
            }

            final query = _query.toLowerCase();
            final items = (snapshot.data ?? const <RecipeSummary>[])
                .where(
                  (recipe) =>
                      recipe.hasPersonalVersion &&
                      (query.isEmpty ||
                          recipe.title.toLowerCase().contains(query)),
                )
                .toList(growable: false);

            if (items.isEmpty) {
              return const _RecipeEmpty(
                message: '아직 저장된 개인 레시피가 없어요.\n요리를 마치고 후기를 남겨보세요.',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('내 레시피 ${items.length}'),
                for (final recipe in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RecipeSummaryTile(
                      summary: recipe,
                      onChanged: _retry,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ResumeCookingCard extends StatelessWidget {
  const _ResumeCookingCard({
    required this.session,
    required this.stepCount,
    required this.onTap,
  });

  final PersistedCookingSession session;
  final int stepCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppShape.container),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이어서 요리하기',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.recipeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.stepIndex + 1} / $stepCount 단계',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeSummaryTile extends StatelessWidget {
  const _RecipeSummaryTile({required this.summary, this.onChanged});

  final RecipeSummary summary;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return FoodTile(
      title: summary.title,
      subtitle: summary.description,
      image: summary.imageUrl,
      trailing: Icon(
        summary.favorite ? Icons.bookmark_rounded : Icons.chevron_right_rounded,
        color: summary.favorite ? AppColors.accent : AppColors.muted,
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _RecipeDetailLoader(summary: summary),
          ),
        );
        onChanged?.call();
      },
    );
  }
}

class _RecipeDetailLoader extends StatefulWidget {
  const _RecipeDetailLoader({required this.summary});

  final RecipeSummary summary;

  @override
  State<_RecipeDetailLoader> createState() => _RecipeDetailLoaderState();
}

class _RecipeDetailLoaderState extends State<_RecipeDetailLoader> {
  late Future<Recipe> _recipe;

  @override
  void initState() {
    super.initState();
    _recipe = _recipeRepository.findById(widget.summary);
  }

  void _retry() {
    setState(() => _recipe = _recipeRepository.findById(widget.summary));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Recipe>(
      future: _recipe,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.summary.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.summary.title)),
            body: _RecipeLoadError(onRetry: _retry),
          );
        }
        return RecipeDetailScreen(recipe: snapshot.data!);
      },
    );
  }
}

class _RecipeLoading extends StatelessWidget {
  const _RecipeLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RecipeLoadError extends StatelessWidget {
  const _RecipeLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.muted, size: 40),
          const SizedBox(height: 12),
          const Text(
            '레시피를 불러오지 못했어요.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '백엔드 서버 연결을 확인한 뒤 다시 시도해 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _RecipeEmpty extends StatelessWidget {
  const _RecipeEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate),
        ),
      ),
    );
  }
}

class _HomeDataEmpty extends StatelessWidget {
  const _HomeDataEmpty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return InfoStrip(icon: icon, title: title, body: body);
  }
}

class _HomeCatalog {
  const _HomeCatalog({
    required this.summaries,
    required this.featured,
    required this.recent,
    required this.favorites,
  });

  final List<RecipeSummary> summaries;
  final Recipe? featured;
  final List<RecipeSummary> recent;
  final List<RecipeSummary> favorites;
}
