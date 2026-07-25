import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../cooking/application/cooking_session_store.dart';
import 'cook_flow_screens.dart';
import 'mock_data.dart';
import 'mvp_widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const SearchScreen(),
      const MemoryScreen(),
    ];

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

  PersistedCookingSession? _resumableSession;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return '좋은 아침이에요';
    if (hour < 17) return '점심은 챙기셨나요?';
    return '오늘 저녁, 뭐 해먹을까요?';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadResumableSession());
  }

  /// 저장된 조리 세션이 있으면 복귀 배너를 띄운다.
  /// 레시피를 찾을 수 없는 저장본은 복원할 수 없으므로 정리한다.
  Future<void> _loadResumableSession() async {
    final session = await _sessionStore.load();
    if (!mounted) {
      return;
    }
    if (session == null || !session.isResumable || _findRecipe(session) == null) {
      if (session != null) {
        unawaited(_sessionStore.clear());
      }
      setState(() => _resumableSession = null);
      return;
    }
    setState(() => _resumableSession = session);
  }

  Recipe? _findRecipe(PersistedCookingSession session) {
    for (final recipe in recipes) {
      if (recipe.title == session.recipeTitle && recipe.steps.isNotEmpty) {
        return recipe;
      }
    }
    return null;
  }

  Future<void> _resumeCooking(PersistedCookingSession session) async {
    final recipe = _findRecipe(session);
    if (recipe == null) {
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // 인사말 헤더 + 프로필
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
            const SizedBox(height: 18),
            // 진행 중이던 조리 세션 복귀 배너
            if (_resumableSession case final PersistedCookingSession session) ...[
              _ResumeCookingCard(
                session: session,
                stepCount:
                    _findRecipe(session)?.steps.length ?? session.stepIndex + 1,
                onTap: () => unawaited(_resumeCooking(session)),
              ),
              const SizedBox(height: 16),
            ],
            // 검색 필드
            TextField(
              readOnly: true,
              onTap: () {},
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
                hintText: '오늘은 어떤 요리를 해볼까요?',
              ),
            ),
            const SizedBox(height: 16),
            // 카테고리 칩
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) =>
                    Pill(categories[i], selected: i == 0),
              ),
            ),
            SectionTitle('오늘의 메뉴', onMore: () {}),
            RecipeHeroCard(
              recipe: tofuRecipe,
              onTap: () => unawaited(_openDetail(context, tofuRecipe)),
            ),
            SectionTitle('최근 조리', onMore: () {}),
            _CardCarousel(
              items: recentCooked,
              onTap: () => unawaited(_openDetail(context, tofuRecipe)),
            ),
            SectionTitle('즐겨찾기', onMore: () {}),
            _CardCarousel(
              items: favorites,
              onTap: () => unawaited(_openDetail(context, tofuRecipe)),
            ),
            SectionTitle('오늘 뭐 먹지?', onMore: () {}),
            _CardCarousel(
              items: todayPicks,
              onTap: () => unawaited(_openDetail(context, tofuRecipe)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Recipe recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailScreen(recipe: recipe),
      ),
    );
    if (mounted) {
      unawaited(_loadResumableSession());
    }
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '검색',
      children: [
        const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            suffixIcon: Icon(Icons.close_rounded, color: AppColors.muted),
            hintText: '두부',
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill('15분 이내', selected: true),
            Pill('한식'),
            Pill('매운맛 낮음'),
            Pill('필터 +'),
          ],
        ),
        const SectionTitle('검색 결과 24'),
        for (final recipe in recipes)
          FoodTile(
            title: recipe.title,
            subtitle: '${recipe.minutes}분 · ${recipe.difficulty}',
            image: recipe.image,
            rating: recipe.rating,
            reviewCount: recipe.reviewCount,
            trailing: const Icon(
              Icons.bookmark_outline_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipeDetailScreen(recipe: recipe),
              ),
            ),
          ),
      ],
    );
  }
}

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: '레시피 메모리',
      children: [
        const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            hintText: '저장한 레시피 검색',
          ),
        ),
        const SectionTitle('두부 조림'),
        const InfoStrip(
          icon: Icons.auto_awesome_rounded,
          title: '버전 3개 · 최근 조리 오늘',
          body: '나 맞춤 ★5 · 변형 2 · 기본 레시피',
        ),
        const SizedBox(height: 10),
        for (final memory in memories)
          FoodTile(
            title: memory.variant,
            subtitle: memory.summary,
            image: memory.image,
            rating: memory.rating,
            trailing: Text(
              memory.lastCooked.split(' ').first,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        PressableScale(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CookSetupScreen(recipe: tofuRecipe),
              ),
            ),
            child: const Text('선택한 버전으로 조리'),
          ),
        ),
      ],
    );
  }
}

/// 진행 중이던 조리 세션으로 되돌아가는 홈 상단 배너.
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
            border: Border.all(color: AppColors.accent),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.accent,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이어서 조리하기',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.recipeTitle} · '
                      '${session.stepIndex + 1}/$stepCount단계 · '
                      '${session.servings}인분',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardCarousel extends StatelessWidget {
  const _CardCarousel({required this.items, required this.onTap});

  final List<RecipeCardData> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) =>
            RecipeCardSmall(data: items[index], onTap: onTap),
      ),
    );
  }
}
