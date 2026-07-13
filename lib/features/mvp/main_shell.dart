import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
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
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: '메모리',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'CookPilot',
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.menu_rounded)),
      ],
      children: [
        TextField(
          readOnly: true,
          onTap: () {},
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: '레시피 이름·재료 검색',
          ),
        ),
        const SectionTitle('오늘의 메뉴'),
        RecipeHeroCard(recipe: tofuRecipe, onTap: () => _openDetail(context)),
        const SectionTitle('최근 조리'),
        _HorizontalRecipeList(
          items: const ['김치볶음밥', '된장찌개', '오일 파스타'],
          labels: const ['나 맞춤', '기본', '변형 1'],
          onTap: () => _openDetail(context),
        ),
        const SectionTitle('즐겨찾기'),
        _HorizontalRecipeList(
          items: const ['두부 조림', '닭갈비', '크림 파스타'],
          labels: const ['나 맞춤', '기본', '변형 1'],
          onTap: () => _openDetail(context),
        ),
        const SectionTitle('오늘 뭐 먹지?'),
        _HorizontalRecipeList(
          items: const ['매콤 제육', '두부 조림', '치킨 샐러드'],
          labels: const ['인기', '추천', '가벼움'],
          onTap: () => _openDetail(context),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RecipeDetailScreen(recipe: tofuRecipe),
      ),
    );
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
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: Icon(Icons.close_rounded),
            hintText: '두부',
          ),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [Pill('15분 이내'), Pill('한식'), Pill('매운맛 낮음'), Pill('필터 +')],
        ),
        const SectionTitle('검색 결과 24'),
        for (final recipe in recipes)
          FoodTile(
            title: recipe.title,
            subtitle:
                '${recipe.minutes}분 · ${recipe.difficulty} · ★ ${recipe.rating}',
            trailing: const Icon(Icons.star_border_rounded),
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
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
      ],
      children: [
        const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.variant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    memory.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.slate),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${memory.lastCooked} · ★ ${memory.rating}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CookSetupScreen(recipe: tofuRecipe),
            ),
          ),
          child: const Text('선택한 버전으로 조리'),
        ),
      ],
    );
  }
}

class _HorizontalRecipeList extends StatelessWidget {
  const _HorizontalRecipeList({
    required this.items,
    required this.labels,
    required this.onTap,
  });

  final List<String> items;
  final List<String> labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          return SizedBox(
            width: 104,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FoodPreview(size: 84),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          items[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 11,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}
