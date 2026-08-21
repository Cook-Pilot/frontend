import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/cooklog_mark.dart';
import '../../design/cookpilot_spacing.dart';
import '../auth/data/auth_session.dart';
import '../cooking/application/cooking_session_store.dart';
import '../cooking/data/exception_advice_api.dart';
import '../cooking/presentation/native_speech_output.dart';
import '../recipe/data/recipe_api.dart';
import '../recipe/data/tag_api.dart';
import '../recipe/domain/recipe.dart';
import '../recipe/domain/tag_invitations.dart';
import '../review/application/pending_review_draft_store.dart';
import '../review/data/review_api.dart';
import '../user/data/profile_onboarding_cache.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'cook_flow_screens.dart';
import 'shell_tab.dart';
import 'mvp_widgets.dart';

final _recipeRepository = RecipeRepository();
final _tagRepository = TagRepository();

typedef HomeReviewScreenBuilder =
    Widget Function(PendingReviewDraft initialDraft);
typedef HomePendingReviewDraftLoader = Future<PendingReviewDraft?> Function();
typedef HomeCookingSessionLoader = Future<PersistedCookingSession?> Function();
typedef HomeCookingScreenBuilder =
    Widget Function(PersistedCookingSession session, Recipe recipe);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    shellTabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    shellTabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  int get index => shellTabIndex.value;

  // 로그인 상태가 바뀔 때마다 올린다. 홈의 key 가 바뀌면서 개인화 데이터를
  // 다시 불러온다 — 다른 탭에서 로그인해도 홈이 낡은 게스트 화면으로 남지 않는다.
  int _sessionEpoch = 0;

  void _onSessionChanged() => setState(() => _sessionEpoch++);

  void _select(int value) => shellTabIndex.value = value;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: ValueKey('home-session-$_sessionEpoch')),
      const SearchScreen(),
      MemoryScreen(onLoggedIn: _onSessionChanged),
      AccountScreen(onSessionChanged: _onSessionChanged),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: _select,
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
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: '기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.recipeRepository,
    this.pendingReviewDraftLoader,
    this.cookingSessionLoader,
    this.reviewScreenBuilder,
    this.cookingScreenBuilder,
  });

  final RecipeRepository? recipeRepository;
  final HomePendingReviewDraftLoader? pendingReviewDraftLoader;
  final HomeCookingSessionLoader? cookingSessionLoader;
  final HomeReviewScreenBuilder? reviewScreenBuilder;
  final HomeCookingScreenBuilder? cookingScreenBuilder;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RecipeRepository _homeRecipeRepository;
  late final CookingSessionStore _sessionStore;
  late final HomePendingReviewDraftLoader _pendingReviewDraftLoader;
  late final HomeCookingSessionLoader _cookingSessionLoader;

  late Future<_HomeCatalog> _catalog;
  var _recoveryGeneration = 0;
  var _recoveryLoading = true;
  Object? _recoveryError;
  PendingReviewDraft? _pendingReviewDraft;
  PersistedCookingSession? _resumableSession;
  Recipe? _resumableRecipe;
  bool _resumingCooking = false;
  var _openingPendingReview = false;

  @override
  void initState() {
    super.initState();
    _homeRecipeRepository = widget.recipeRepository ?? _recipeRepository;
    _sessionStore = const CookingSessionStore();
    _pendingReviewDraftLoader =
        widget.pendingReviewDraftLoader ?? PendingReviewDraftStore().load;
    _cookingSessionLoader = widget.cookingSessionLoader ?? _sessionStore.load;
    _catalog = _loadCatalog();
    unawaited(_refreshRecovery(markLoading: false));
  }

  /// 한 번에 보낼 태그 조회 수. 서버가 EC2 한 대라 24개를 동시에 던지지 않는다.
  static const _tagFetchBatch = 6;

  /// 열 하나에 담을 레시피 수. 가로 열은 지연 생성이라 화면 밖 카드는 그리지 않는다.
  static const _tagRowSize = 12;

  /// 홈에 띄울 태그 열의 최대 수.
  static const _tagRowLimit = 12;

  Future<_HomeCatalog> _loadCatalog() async {
    // 최근 조리·즐겨찾기는 계정에 속한 데이터라 게스트에게는 없다.
    // 요청을 보내 봐야 401 이므로 아예 부르지 않는다.
    final loggedIn = AuthSession.isLoggedIn;
    final results = await Future.wait<List<RecipeSummary>>([
      _homeRecipeRepository.findAll(),
      if (loggedIn) _homeRecipeRepository.findRecent(),
      if (loggedIn) _homeRecipeRepository.findFavorites(),
    ]);
    final summaries = results[0];
    final recent = loggedIn ? results[1] : const <RecipeSummary>[];
    final favorites = loggedIn ? results[2] : const <RecipeSummary>[];
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
      featured = await _homeRecipeRepository.findById(summaries.first);
    } on Object {
      // 추천 상세가 실패해도 조회 가능한 전체 목록은 유지한다.
      featured = null;
    }
    return _HomeCatalog(
      summaries: summaries,
      featured: featured,
      recent: recent,
      favorites: favorites,
      tagRows: await _loadTagRows(),
    );
  }

  /// 태그 열 세 개를 뽑는다.
  ///
  /// 태그를 무작위로 고르므로 홈을 열 때마다 구성이 달라진다 — 카탈로그가 1,150건으로
  /// 고정돼 있어도 매번 다른 요리가 눈에 들어온다.
  ///
  /// 실패해도 홈 전체를 막지 않는다. 태그 열은 있으면 좋은 것이지 없으면 못 쓰는 화면이
  /// 아니다(레시피 목록·최근 조리는 그대로 나온다).
  Future<List<_TagRow>> _loadTagRows() async {
    try {
      final tags = await _tagRepository.findAll();
      // 권유 문장을 준비해 둔 태그만 후보로 쓴다.
      final candidates =
          tags.where((tag) => TagInvitations.hasPhrase(tag.code)).toList()
            ..shuffle();

      final rows = <_TagRow>[];
      for (var from = 0; from < candidates.length; from += _tagFetchBatch) {
        if (rows.length >= _tagRowLimit) break;
        final batch = candidates.skip(from).take(_tagFetchBatch).toList();
        final pages = await Future.wait(
          batch.map(
            (tag) => _homeRecipeRepository
                .search(tags: [tag.code], size: _tagRowSize)
                .then<RecipeSearchPage?>((page) => page)
                // 한 태그가 실패해도 나머지 열은 살린다.
                .onError((_, _) => null),
          ),
        );
        for (var i = 0; i < batch.length; i++) {
          final page = pages[i];
          // 비어 있는 태그는 건너뛴다 — 빈 열은 고장으로 보인다.
          if (page == null || page.items.isEmpty) continue;
          final tag = batch[i];
          rows.add(
            _TagRow(
              invitation: TagInvitations.forTag(tag.code, tag.label),
              label: tag.label,
              recipes: page.items,
            ),
          );
        }
      }
      return rows;
    } on Object {
      return const [];
    }
  }

  void _retry() {
    setState(() {
      _catalog = _loadCatalog();
    });
    unawaited(_refreshRecovery());
  }

  void _refreshHome() {
    _retry();
  }

  /// 홈의 게스트 안내 카드에서 로그인으로. 성공하면 개인화 데이터를 다시 그린다.
  Future<void> _signInFromHome() async {
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
    if (!mounted || loggedIn != true || !AuthSession.isLoggedIn) return;
    unawaited(ProfileOnboardingCache.refresh());
    _refreshHome();
  }

  /// 카드에서 레시피 상세로. 돌아오면 즐겨찾기·개인 버전 변화가 반영되도록 다시 읽는다.
  void _openRecipe(RecipeSummary summary) {
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => _RecipeDetailLoader(summary: summary),
            ),
          )
          .then((_) => _refreshHome()),
    );
  }

  /// 오늘의 메뉴는 이미 전체 레시피를 들고 있어 다시 불러올 필요가 없다.
  void _openFeatured(Recipe recipe) {
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          )
          .then((_) => _refreshHome()),
    );
  }

  bool _isCurrentRecovery(int generation) {
    return mounted && generation == _recoveryGeneration;
  }

  Future<void> _refreshRecovery({bool markLoading = true}) async {
    final generation = ++_recoveryGeneration;
    if (markLoading && mounted) {
      setState(() {
        _recoveryLoading = true;
        _recoveryError = null;
        _pendingReviewDraft = null;
        _resumableSession = null;
        _resumableRecipe = null;
      });
    }

    try {
      final pendingReviewDraft = await _pendingReviewDraftLoader();
      if (!_isCurrentRecovery(generation)) {
        return;
      }
      if (pendingReviewDraft != null) {
        setState(() {
          _recoveryLoading = false;
          _recoveryError = null;
          _pendingReviewDraft = pendingReviewDraft;
          _resumableSession = null;
          _resumableRecipe = null;
        });
        return;
      }

      _ResumableCooking? resumableCooking;
      Object? resumableCookingError;
      StackTrace? resumableCookingStackTrace;
      try {
        resumableCooking = await _findResumableCooking(generation);
      } on Object catch (error, stackTrace) {
        resumableCookingError = error;
        resumableCookingStackTrace = stackTrace;
      }
      if (!_isCurrentRecovery(generation)) {
        return;
      }
      // The active-session lookup can outlive cooking completion. Re-read the
      // draft even when that lookup failed, so a review created while it was
      // running still wins.
      final latestPendingReviewDraft = await _pendingReviewDraftLoader();
      if (!_isCurrentRecovery(generation)) {
        return;
      }
      if (latestPendingReviewDraft == null && resumableCookingError != null) {
        Error.throwWithStackTrace(
          resumableCookingError,
          resumableCookingStackTrace!,
        );
      }
      setState(() {
        _recoveryLoading = false;
        _recoveryError = null;
        _pendingReviewDraft = latestPendingReviewDraft;
        _resumableSession = latestPendingReviewDraft == null
            ? resumableCooking?.session
            : null;
        _resumableRecipe = latestPendingReviewDraft == null
            ? resumableCooking?.recipe
            : null;
      });
    } on Object catch (error) {
      if (!_isCurrentRecovery(generation)) {
        return;
      }
      setState(() {
        _recoveryLoading = false;
        _recoveryError = error;
        _pendingReviewDraft = null;
        _resumableSession = null;
        _resumableRecipe = null;
      });
    }
  }

  Future<_ResumableCooking?> _findResumableCooking(int generation) async {
    final session = await _cookingSessionLoader();
    if (!_isCurrentRecovery(generation)) {
      return null;
    }
    if (session == null || !session.isResumable) {
      return null;
    }

    final storedRecipeId = session.recipeId;
    try {
      var restoredSession = session;
      final Recipe recipe;
      final setupSnapshot = session.setupSnapshot;
      if (setupSnapshot != null) {
        recipe = setupSnapshot.toExecutionRecipe();
      } else {
        final recipeId = storedRecipeId;
        if (recipeId != null && recipeId.isNotEmpty) {
          recipe = await _homeRecipeRepository.findByRecipeId(recipeId);
        } else {
          final summaries = await _homeRecipeRepository.findAll();
          final matches = summaries
              .where((summary) => summary.title == session.recipeTitle)
              .toList(growable: false);
          if (matches.length != 1) {
            return null;
          }
          recipe = await _homeRecipeRepository.findById(matches.single);
        }
      }
      if (recipe.steps.isEmpty) {
        return null;
      }
      if (session.recipeId != recipe.id ||
          session.recipeTitle != recipe.title) {
        restoredSession = session.copyWith(
          recipeId: recipe.id,
          recipeTitle: recipe.title,
        );
      }
      return _ResumableCooking(session: restoredSession, recipe: recipe);
    } on RecipeApiException catch (error) {
      if (storedRecipeId == null ||
          storedRecipeId.isEmpty ||
          error.statusCode != 404) {
        rethrow;
      }
      return null;
    }
  }

  Future<void> _openPendingReview() async {
    final pendingReviewDraft = _pendingReviewDraft;
    if (pendingReviewDraft == null || _openingPendingReview) {
      return;
    }
    _openingPendingReview = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              widget.reviewScreenBuilder?.call(pendingReviewDraft) ??
              ReviewScreen(initialDraft: pendingReviewDraft),
        ),
      );
    } finally {
      _openingPendingReview = false;
    }
    if (mounted) {
      await _refreshRecovery();
    }
  }

  Future<void> _resumeCooking() async {
    if (_resumingCooking) {
      return;
    }
    final session = _resumableSession;
    final recipe = _resumableRecipe;
    if (session == null || recipe == null) {
      return;
    }
    final generation = ++_recoveryGeneration;
    setState(() => _resumingCooking = true);
    try {
      final PendingReviewDraft? latestPendingReviewDraft;
      try {
        latestPendingReviewDraft = await _pendingReviewDraftLoader();
      } on Object catch (error) {
        if (_isCurrentRecovery(generation)) {
          setState(() {
            _recoveryLoading = false;
            _recoveryError = error;
            _pendingReviewDraft = null;
            _resumableSession = null;
            _resumableRecipe = null;
          });
        }
        return;
      }
      if (!_isCurrentRecovery(generation)) {
        return;
      }
      // Keep the explicit check for BuildContext use after the async load.
      if (!mounted) {
        return;
      }
      if (latestPendingReviewDraft != null) {
        setState(() {
          _recoveryLoading = false;
          _recoveryError = null;
          _pendingReviewDraft = latestPendingReviewDraft;
          _resumableSession = null;
          _resumableRecipe = null;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('작성 중인 후기를 먼저 이어갈게요.')));
        await _openPendingReview();
        return;
      }

      // MaterialPageRoute.builder는 재실행될 수 있으므로 화면이 소유할 포트는
      // 밖에서 한 번만 만든다.
      final advicePort = HttpExceptionAdvicePort();
      final speechOutput = NativeSpeechOutput();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              widget.cookingScreenBuilder?.call(session, recipe) ??
              CookSessionScreen(
                recipe: recipe,
                servings: session.servings,
                setupSnapshot: session.setupSnapshot,
                restoredSession: session,
                advicePort: advicePort,
                speechOutput: speechOutput,
              ),
        ),
      );
      if (mounted) {
        unawaited(_refreshRecovery());
      }
    } finally {
      if (mounted) {
        setState(() => _resumingCooking = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    final nextCatalog = _loadCatalog();
    setState(() {
      _catalog = nextCatalog;
    });
    final nextRecovery = _refreshRecovery();
    await Future.wait([nextCatalog, nextRecovery]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  // 인사말 대신 워드마크만 둔다. 넷플릭스 좌상단과 같은 자리다.
                  // 검색은 하단 탭에 있으므로 여기에 또 두지 않는다.
                  const CookLogMark(size: 28),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/logo/cooklog-wordmark.png',
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                ],
              ),
              if (_recoveryLoading) ...[
                const SizedBox(height: 18),
                const _HomeRecoveryLoadingCard(),
              ] else if (_recoveryError != null) ...[
                const SizedBox(height: 18),
                _HomeRecoveryErrorCard(
                  onRetry: () => unawaited(_refreshRecovery()),
                ),
              ] else if (_pendingReviewDraft
                  case final PendingReviewDraft draft) ...[
                const SizedBox(height: 18),
                _ResumeReviewCard(
                  draft: draft,
                  onTap: () => unawaited(_openPendingReview()),
                ),
              ] else if (_resumableSession
                  case final PersistedCookingSession session) ...[
                const SizedBox(height: 18),
                _ResumeCookingCard(
                  session: session,
                  stepCount:
                      _resumableRecipe?.steps.length ?? session.stepIndex + 1,
                  checkingPendingReview: _resumingCooking,
                  onTap: _resumingCooking
                      ? null
                      : () => unawaited(_resumeCooking()),
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
                      if (catalog.featured != null)
                        RecipeHeroCard(
                          recipe: catalog.featured!,
                          onTap: () => _openFeatured(catalog.featured!),
                        ),
                      // 게스트는 개인화 열을 채울 데이터가 없다. 열을 비워 두는 대신
                      // 로그인 안내로 갈아 끼운다 — 빈 가로 열은 고장으로 보인다.
                      if (!AuthSession.isLoggedIn) ...[
                        const SectionTitle('내가 만든 요리'),
                        _GuestLoginInvite(
                          inviteKey: const Key('home-recent-login-invite'),
                          icon: Icons.history_rounded,
                          title: '로그인하면 조리 기록이 여기 남아요',
                          body: '요리를 마치고 남긴 후기가 최근 조리로 쌓여요.',
                          onLogin: _signInFromHome,
                        ),
                        const SectionTitle('다시 만들까요'),
                        _GuestLoginInvite(
                          inviteKey: const Key('home-favorites-login-invite'),
                          icon: Icons.bookmark_outline_rounded,
                          title: '로그인하면 즐겨찾기를 모아볼 수 있어요',
                          body: '마음에 드는 레시피를 저장해 두고 바로 꺼내 봐요.',
                          onLogin: _signInFromHome,
                        ),
                      ] else ...[
                        if (catalog.recent.isNotEmpty)
                          RecipeRail(
                            title: '내가 만든 요리',
                            trailing: '전체 ${catalog.recent.length}',
                            children: [
                              for (final recipe in catalog.recent)
                                RecipePosterCard(
                                  title: recipe.title,
                                  image: recipe.imageUrl,
                                  meta: recipe.hasPersonalVersion
                                      ? '내 버전 있음'
                                      : null,
                                  onTap: () => _openRecipe(recipe),
                                ),
                            ],
                          )
                        else
                          const _HomeDataEmpty(
                            icon: Icons.history_rounded,
                            title: '아직 만든 요리가 없어요',
                            body: '첫 요리를 마치고 후기를 남기면 여기에 모여요.',
                          ),
                        if (catalog.favorites.isNotEmpty)
                          RecipeRail(
                            title: '다시 만들까요',
                            trailing: '즐겨찾기 ${catalog.favorites.length}',
                            children: [
                              for (final recipe in catalog.favorites)
                                RecipePosterCard(
                                  title: recipe.title,
                                  image: recipe.imageUrl,
                                  onTap: () => _openRecipe(recipe),
                                ),
                            ],
                          ),
                      ],
                      for (final row in catalog.tagRows)
                        RecipeRail(
                          title: row.invitation,
                          trailing: row.label,
                          children: [
                            for (final recipe in row.recipes)
                              RecipePosterCard(
                                title: recipe.title,
                                image: recipe.imageUrl,
                                onTap: () => _openRecipe(recipe),
                              ),
                          ],
                        ),
                      RecipeRail(
                        title: '전체 레시피',
                        trailing: '${catalog.summaries.length}개',
                        children: [
                          for (final recipe in catalog.summaries)
                            RecipePosterCard(
                              title: recipe.title,
                              image: recipe.imageUrl,
                              onTap: () => _openRecipe(recipe),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
  const SearchScreen({super.key, this.recipeRepository});

  final RecipeRepository? recipeRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

/// 검색창을 처음 열었을 때 무엇을 칠 수 있는지 보여주는 예시.
/// 카탈로그에서 실제로 결과가 많은 재료들이다.
const _searchHints = ['두부', '계란', '김치', '돼지고기', '양파', '애호박', '감자'];

class _SearchScreenState extends State<SearchScreen> {
  void _openRecipe(RecipeSummary summary) {
    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => _RecipeDetailLoader(summary: summary),
            ),
          )
          .then((_) => _retry()),
    );
  }

  static const _pageSize = 9;

  late final RecipeRepository _searchRecipeRepository;
  late final TextEditingController _titleController;
  late final TextEditingController _ingredientController;
  late Future<RecipeSearchPage> _results;
  String _title = '';
  String _ingredient = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _searchRecipeRepository = widget.recipeRepository ?? _recipeRepository;
    _titleController = TextEditingController();
    _ingredientController = TextEditingController();
    _results = _loadResults();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  Future<RecipeSearchPage> _loadResults() {
    return _searchRecipeRepository.search(
      title: _title,
      ingredient: _ingredient,
      page: _page,
      size: _pageSize,
    );
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _title = _titleController.text.trim();
      _ingredient = _ingredientController.text.trim();
      _page = 1;
      _results = _loadResults();
    });
  }

  void _clearSearch() {
    _titleController.clear();
    _ingredientController.clear();
    setState(() {
      _title = '';
      _ingredient = '';
      _page = 1;
      _results = _loadResults();
    });
  }

  void _loadPage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _results = _loadResults();
    });
  }

  void _retry() {
    setState(() => _results = _loadResults());
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      homeLogo: true,
      title: '검색',
      children: [
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            labelText: '요리 이름',
            hintText: '예: 가지 탕수육',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ingredientController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submitSearch(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.kitchen_rounded, color: AppColors.muted),
            labelText: '재료',
            hintText: '예: 두부',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _submitSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('검색'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _clearSearch,
                child: const Text('초기화'),
              ),
            ),
          ],
        ),
        const SectionTitle('이렇게 찾아보세요'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ingredient in _searchHints)
              ActionChip(
                label: Text(ingredient),
                onPressed: () {
                  _ingredientController.text = ingredient;
                  _submitSearch();
                },
              ),
          ],
        ),
        FutureBuilder<RecipeSearchPage>(
          future: _results,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _RecipeLoading();
            }
            if (snapshot.hasError) {
              return _RecipeLoadError(onRetry: _retry);
            }

            final result = snapshot.data;
            final items = result?.items ?? const <RecipeSummary>[];

            if (items.isEmpty) {
              return const _RecipeEmpty(message: '조건에 맞는 레시피가 없어요.');
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle('검색 결과 ${result!.totalItems}'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final recipe = items[index];
                    return RecipePosterCard(
                      title: recipe.title,
                      image: recipe.imageUrl,
                      width: double.infinity,
                      onTap: () => _openRecipe(recipe),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (result.totalPages > 1)
                  _RecipePagination(
                    page: result.page,
                    totalPages: result.totalPages,
                    onPageSelected: _loadPage,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecipePagination extends StatelessWidget {
  const _RecipePagination({
    required this.page,
    required this.totalPages,
    required this.onPageSelected,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final canGoBack = page > 1;
    final canGoForward = page < totalPages;

    Widget pageButton({
      required String tooltip,
      required IconData icon,
      required int targetPage,
      required bool enabled,
    }) {
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.standard,
        constraints: const BoxConstraints.tightFor(
          width: CookPilotSpacing.minimumTapTarget,
          height: CookPilotSpacing.minimumTapTarget,
        ),
        onPressed: enabled ? () => onPageSelected(targetPage) : null,
        icon: Icon(icon),
      );
    }

    // 48dp 탭 타겟을 지키면서 360dp 폭 기기에서 한 줄을 유지하려면
    // 컨트롤은 4개(처음·이전·다음·마지막)까지다. ±5 점프를 두면 일곱 개가
    // 한 줄에 못 들어가 마지막 버튼이 다음 줄로 밀린다(실기기 제보).
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          pageButton(
            tooltip: '처음 페이지',
            icon: Icons.first_page_rounded,
            targetPage: 1,
            enabled: canGoBack,
          ),
          pageButton(
            tooltip: '이전 페이지',
            icon: Icons.chevron_left_rounded,
            targetPage: page - 1,
            enabled: canGoBack,
          ),
          SizedBox(
            width: 72,
            child: Text(
              '$page / $totalPages',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          pageButton(
            tooltip: '다음 페이지',
            icon: Icons.chevron_right_rounded,
            targetPage: page + 1,
            enabled: canGoForward,
          ),
          pageButton(
            tooltip: '마지막 페이지',
            icon: Icons.last_page_rounded,
            targetPage: totalPages,
            enabled: canGoForward,
          ),
        ],
      ),
    );
  }
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({
    super.key,
    this.reviewRepository,
    this.initialDate,
    this.onLoggedIn,
  });

  /// 이 탭에서 로그인에 성공했을 때. 셸이 홈을 다시 그리는 데 쓴다.
  final VoidCallback? onLoggedIn;

  final ReviewRepository? reviewRepository;
  final DateTime? initialDate;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late final ReviewRepository _reviewRepository;
  late DateTime _month;
  late DateTime _selectedDate;
  late Future<List<CookingHistoryEntry>> _history;

  @override
  void initState() {
    super.initState();
    _reviewRepository = widget.reviewRepository ?? ReviewRepository();
    final today = widget.initialDate ?? DateTime.now();
    _month = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
    // 조리 기록은 계정 데이터다. 게스트는 요청을 만들지 않는다 —
    // 만들면 리스너 없는 실패 Future 가 미처리 오류로 남는다.
    _history = AuthSession.isLoggedIn
        ? _loadMonth()
        : Future.value(const <CookingHistoryEntry>[]);
  }

  /// 게스트가 로그인 버튼을 눌렀을 때. 로그인까지 마치면 기록을 불러온다.
  Future<void> _signInFromMemory() async {
    final loggedIn = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const AuthScreen()));
    if (!mounted || loggedIn != true || !AuthSession.isLoggedIn) return;
    unawaited(ProfileOnboardingCache.refresh());
    widget.onLoggedIn?.call();
    setState(() {
      _history = _loadMonth();
    });
  }

  Future<List<CookingHistoryEntry>> _loadMonth() {
    return _reviewRepository.findHistory(
      from: _month,
      to: DateTime(_month.year, _month.month + 1),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDate = _month;
      _history = _loadMonth();
    });
  }

  void _retry() {
    setState(() {
      _history = _loadMonth();
    });
  }

  void _openHistoryDetail(
    CookingHistoryEntry selected,
    List<CookingHistoryEntry> monthEntries,
  ) {
    final sameRecipe =
        monthEntries
            .where((entry) => entry.recipeId == selected.recipeId)
            .toList(growable: false)
          ..sort((left, right) => right.cookedAt.compareTo(left.cookedAt));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CookingHistoryDetailScreen(
            entry: selected,
            sameRecipeEntries: sameRecipe,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 게스트에게는 달력·기록 대신 로그인 안내를 보여준다.
    // 기록이 없는 게 아니라 '계정이 없어서 보여줄 수 없는' 상태이기 때문이다.
    if (!AuthSession.isLoggedIn) {
      return PageShell(
        title: '레시피 메모리',
        children: [
          const SizedBox(height: 48),
          const Center(
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 48,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '로그인하면 조리 기록이 여기 모여요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '요리를 마치고 남긴 후기가 달력으로 정리됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              key: const Key('memory-login-button'),
              onPressed: () => unawaited(_signInFromMemory()),
              icon: const Icon(Icons.login_rounded),
              label: const Text('로그인하기'),
            ),
          ),
        ],
      );
    }

    return PageShell(
      homeLogo: true,
      title: '레시피 메모리',
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${_month.year}년 ${_month.month}월',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        FutureBuilder<List<CookingHistoryEntry>>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _RecipeLoading();
            }
            if (snapshot.hasError) {
              return _RecipeLoadError(onRetry: _retry);
            }

            final entries = snapshot.data ?? const <CookingHistoryEntry>[];
            final entriesByDay = <int, List<CookingHistoryEntry>>{};
            for (final entry in entries) {
              entriesByDay.putIfAbsent(entry.cookedAt.day, () => []).add(entry);
            }
            final selectedEntries = entries
                .where((entry) => _isSameDate(entry.cookedAt, _selectedDate))
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in ['일', '월', '화', '수', '목', '금', '토'])
                      Expanded(
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  children: [
                    for (var index = 0; index < _month.weekday % 7; index++)
                      const SizedBox.shrink(),
                    for (
                      var day = 1;
                      day <= DateTime(_month.year, _month.month + 1, 0).day;
                      day++
                    )
                      _MemoryCalendarDay(
                        day: day,
                        count: entriesByDay[day]?.length ?? 0,
                        selected:
                            _selectedDate.year == _month.year &&
                            _selectedDate.month == _month.month &&
                            _selectedDate.day == day,
                        onTap: () => setState(
                          () => _selectedDate = DateTime(
                            _month.year,
                            _month.month,
                            day,
                          ),
                        ),
                      ),
                  ],
                ),
                SectionTitle(
                  '${_selectedDate.month}월 ${_selectedDate.day}일 조리',
                ),
                if (selectedEntries.isEmpty)
                  const _RecipeEmpty(message: '이날 저장된 조리 기록이 없어요.')
                else
                  for (final entry in selectedEntries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FoodTile(
                        title: entry.recipeTitle,
                        subtitle:
                            '${entry.rating == null ? '평점 없음' : '★ ${entry.rating}'}'
                            '${entry.createdPersonalVersionNumber == null ? '' : ' · 개인 v${entry.createdPersonalVersionNumber}'}',
                        image: entry.recipeImageUrl,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                        ),
                        onTap: () => _openHistoryDetail(entry, entries),
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

class CookingHistoryDetailScreen extends StatelessWidget {
  const CookingHistoryDetailScreen({
    super.key,
    required this.entry,
    required this.sameRecipeEntries,
  });

  final CookingHistoryEntry entry;
  final List<CookingHistoryEntry> sameRecipeEntries;

  @override
  Widget build(BuildContext context) {
    final otherEntries = sameRecipeEntries
        .where((item) => item.reviewId != entry.reviewId)
        .toList(growable: false);
    final recipeSource = entry.sourcePersonalVersionId == null
        ? '기본 레시피'
        : '개인 레시피';

    return PageShell(
      title: '조리 기록',
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      children: [
        Text(
          entry.recipeTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _fullDateLabel(entry.cookedAt),
          style: const TextStyle(
            color: AppColors.slate,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _CookingResultOverview(entry: entry, recipeSource: recipeSource),
        if (entry.createdPersonalVersionNumber case final int number) ...[
          const SizedBox(height: 14),
          InfoStrip(
            icon: Icons.auto_awesome_rounded,
            title: '개인 레시피 v$number 생성',
            body:
                entry.createdPersonalVersionSummary ??
                '이번 실행 변경을 개인 버전으로 저장했어요.',
          ),
        ],
        if (entry.comment case final String comment
            when comment.isNotEmpty) ...[
          const SectionTitle('이번 요리 메모'),
          _MemoryNoteCard(icon: Icons.edit_note_rounded, text: comment),
        ],
        if (entry.nextTimeNote case final String note when note.isNotEmpty) ...[
          const SectionTitle('다음에는'),
          _MemoryNoteCard(icon: Icons.next_plan_outlined, text: note),
        ],
        if (otherEntries.isNotEmpty) ...[
          const SectionTitle('같은 요리의 다른 기록'),
          for (var index = 0; index < otherEntries.length; index++)
            _CookingHistoryTimelineItem(
              entry: otherEntries[index],
              isLast: index == otherEntries.length - 1,
            ),
        ],
      ],
    );
  }
}

class _CookingResultOverview extends StatelessWidget {
  const _CookingResultOverview({
    required this.entry,
    required this.recipeSource,
  });

  final CookingHistoryEntry entry;
  final String recipeSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.wash,
        borderRadius: BorderRadius.circular(AppShape.container),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppShape.inner),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipeSource,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _ratingLabel(entry.rating),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryNoteCard extends StatelessWidget {
  const _MemoryNoteCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppShape.inner),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CookingHistoryTimelineItem extends StatelessWidget {
  const _CookingHistoryTimelineItem({
    required this.entry,
    required this.isLast,
  });

  final CookingHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final version = entry.createdPersonalVersionNumber;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.line)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullDateLabel(entry.cookedAt),
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_ratingLabel(entry.rating)}'
                    '${version == null ? '' : ' · 개인 v$version 생성'}',
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 13,
                    ),
                  ),
                  if (entry.comment case final String comment
                      when comment.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.slate),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fullDateLabel(DateTime date) {
  return '${date.year}년 ${date.month}월 ${date.day}일';
}

String _ratingLabel(int? rating) {
  if (rating == null) return '평점 없음';
  final safeRating = rating.clamp(0, 5);
  return '${'★' * safeRating}${'☆' * (5 - safeRating)}  $safeRating.0';
}

class _MemoryCalendarDay extends StatelessWidget {
  const _MemoryCalendarDay({
    required this.day,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.ink,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              const SizedBox(height: 13),
          ],
        ),
      ),
    );
  }
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class _HomeRecoveryLoadingCard extends StatelessWidget {
  const _HomeRecoveryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.container),
        border: Border.all(color: AppColors.line),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Text(
              '저장된 진행 상황을 확인하고 있어요.',
              style: TextStyle(
                color: AppColors.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRecoveryErrorCard extends StatelessWidget {
  const _HomeRecoveryErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.container),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.accent),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '저장된 진행 상황을 불러오지 못했어요.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            '후기나 조리 세션이 남아 있을 수 있어요. 다시 확인해 주세요.',
            style: TextStyle(color: AppColors.slate, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _ResumeReviewCard extends StatelessWidget {
  const _ResumeReviewCard({required this.draft, required this.onTap});

  final PendingReviewDraft draft;
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
                  Icons.rate_review_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '후기 작성 이어가기',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      draft.setupSnapshot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '작성 중인 내용을 확인하고 저장해 주세요.',
                      style: TextStyle(color: AppColors.slate, fontSize: 13),
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

class _ResumeCookingCard extends StatelessWidget {
  const _ResumeCookingCard({
    required this.session,
    required this.stepCount,
    required this.checkingPendingReview,
    required this.onTap,
  });

  final PersistedCookingSession session;
  final int stepCount;
  final bool checkingPendingReview;
  final VoidCallback? onTap;

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
                    Text(
                      checkingPendingReview ? '후기 상태 확인 중' : '이어서 요리하기',
                      style: const TextStyle(
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
              if (checkingPendingReview)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
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
            body: const CookLogLoader(label: '레시피 여는 중'),
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
      padding: EdgeInsets.only(top: 56, bottom: 24),
      child: CookLogLoader(label: '불 올리는 중'),
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

/// 게스트에게 보여주는 안내형 로그인 유도 카드. 팝업으로 방해하지 않고,
/// 계정 데이터가 놓일 빈 자리에서 이유와 함께 권한다.
class _GuestLoginInvite extends StatelessWidget {
  const _GuestLoginInvite({
    required this.inviteKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.onLogin,
  });

  final Key inviteKey;
  final IconData icon;
  final String title;
  final String body;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: inviteKey,
      borderRadius: BorderRadius.circular(16),
      onTap: () => unawaited(onLogin()),
      child: InfoStrip(icon: icon, title: title, body: '$body 눌러서 로그인하기'),
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
    this.tagRows = const [],
  });

  final List<RecipeSummary> summaries;
  final Recipe? featured;
  final List<RecipeSummary> recent;
  final List<RecipeSummary> favorites;

  /// 태그로 뽑은 열. 홈을 열 때마다 다른 태그가 뽑힌다.
  final List<_TagRow> tagRows;
}

/// 태그 하나로 만든 홈의 가로 열.
class _TagRow {
  const _TagRow({
    required this.invitation,
    required this.label,
    required this.recipes,
  });

  /// '오늘은 한식 어때요?' 처럼 권유하는 문장.
  final String invitation;

  /// 태그 이름. 열 오른쪽에 작게 붙여 무엇으로 묶였는지 알려준다.
  final String label;
  final List<RecipeSummary> recipes;
}

class _ResumableCooking {
  const _ResumableCooking({required this.session, required this.recipe});

  final PersistedCookingSession session;
  final Recipe recipe;
}
