import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/cooklog_mark.dart';
import '../recipe/domain/recipe.dart';
import 'shell_tab.dart';

/// Wraps a tappable child and scales it down slightly on press, so buttons
/// and cards feel like they are listening the instant they're touched.
/// Uses [Listener] rather than a gesture detector so it never competes with
/// the child's own tap handling (InkWell, GestureDetector, etc.).
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: reduceMotion ? Duration.zero : AppMotion.fast,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 어디서든 홈으로 돌아가는 로고. 넷플릭스 좌상단 로고와 같은 자리, 같은 뜻이다.
///
/// 깊이 들어간 화면(레시피 상세 → 조리 설정 → …)에서 뒤로가기를 여러 번 누르는 대신
/// 한 번에 처음으로 돌아온다. 조리 중에는 붙이지 않는다 — 진행 중인 세션을 실수로
/// 날릴 수 있어 그 화면은 X 버튼이 확인을 거쳐 닫는다.
/// 루트로 돌아간 뒤 홈 탭까지 간다. 둘 중 하나만 하면 '검색 탭의 루트'에 남는다.
void goHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  shellTabIndex.value = shellHomeTab;
}

class HomeLogoButton extends StatelessWidget {
  const HomeLogoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        key: const Key('home-logo'),
        customBorder: const CircleBorder(),
        onTap: () => goHome(context),
        child: const Padding(
          padding: EdgeInsets.all(8),
          // 헤더에서도 김이 계속 오른다. 정지한 로고보다 살아 있어 보인다.
          child: SteamingCookLogMark(size: 34),
        ),
      ),
    );
  }
}

class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.children,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.accentHeader = false,
    this.homeLogo = false,
    this.bleed,
  });

  /// 좌우 여백 없이 화면 끝까지 채우는 요소. 목록 맨 위에 놓인다.
  ///
  /// 본문은 여백 안에서 읽히는 편이 낫지만, 히어로는 사진이 화면을 꽉 채워야
  /// 시선을 잡는다. 여백 안에 두면 카드 하나로 보인다.
  final Widget? bleed;

  /// 상단 오른쪽에 홈으로 가는 로고를 붙인다.
  final bool homeLogo;

  /// 상단바를 주황으로 채운다. 조리를 마치고 후기로 넘어왔다는 신호를 색으로 준다 —
  /// 어두운 조리 화면에서 나온 직후라 밝음/어두움/밝음의 왕복이 흐름의 끝을 만든다.
  final bool accentHeader;

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontalPadding = media.size.width < 390 ? 16.0 : 20.0;

    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              leading: leading,
              titleSpacing: leading == null && homeLogo ? 0 : null,
              title: Row(
                children: [
                  // 넷플릭스처럼 상단 왼쪽. 뒤로가기가 있으면 그 옆에 붙는다.
                  if (homeLogo) ...[
                    const HomeLogoButton(),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: actions,
              backgroundColor: accentHeader ? AppColors.accent : null,
              foregroundColor: accentHeader ? Colors.white : null,
              titleTextStyle: accentHeader
                  ? const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    )
                  : null,
            ),
      body: SafeArea(
        child: ListView(
          // 자식을 하나로 묶지 않는다. Column 으로 싸면 목록이 지연 배치를 잃어
          // 화면 밖 열까지 전부 배치된다(홈은 열이 열두 개다).
          padding: EdgeInsets.zero,
          children: [
            ?bleed,
            SizedBox(height: bleed == null ? 12 : 4),
            for (final child in children)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: child,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                20,
              ),
              child: bottom!,
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.onMore});

  final String title;
  final Widget? trailing;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          ?trailing,
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: const Row(
                children: [
                  Text(
                    '더보기',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 음식 사진. URL이 비어 있거나 로드에 실패하면 플레이스홀더로 대체된다.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.radius = AppShape.inner,
  });

  final String image;
  final double? width;
  final double? height;
  final double radius;

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBEBD9), Color(0xFFF3D8BC)],
        ),
      ),
      child: const Icon(
        Icons.restaurant_rounded,
        color: Color(0xFFC08A5A),
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 디코딩 해상도를 표시 크기로 제한한다. 시드 데이터에 원본급 사진(최대 30MP,
    // 장당 디코딩 ~112MB)이 섞여 있어, 제한 없이 디코딩하면 목록 스크롤만으로
    // iOS 메모리 상한(EXC_RESOURCE)에 걸려 앱이 강제 종료된다.
    // width가 double.infinity로 오는 채움형 배치가 있어(조리 화면 등) 유한한
    // 값일 때만 쓰고, 아니면 화면 폭을 상한으로 삼는다.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth = (width != null && width!.isFinite)
        ? width!
        : MediaQuery.sizeOf(context).width;
    final cacheWidth = (logicalWidth * dpr).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image.isEmpty
          ? _placeholder()
          : Image.network(
              image,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: cacheWidth,
              errorBuilder: (context, error, stack) => _placeholder(),
            ),
    );
  }
}

/// 평점 뱃지 — 파프리카 별 + 점수 (+선택적 리뷰 수).
class RatingBadge extends StatelessWidget {
  const RatingBadge(this.rating, {super.key, this.reviewCount});

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (reviewCount != null) ...[
          const SizedBox(width: 3),
          Text(
            '(${reviewCount! >= 1000 ? '${(reviewCount! / 1000).toStringAsFixed(1)}k' : reviewCount})',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// 이미지 위에 얹는 작은 라벨 칩.
class ImageLabelChip extends StatelessWidget {
  const ImageLabelChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 검색 결과·목록용 가로형 타일. 실제 음식 썸네일 포함.
class FoodTile extends StatelessWidget {
  const FoodTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.image,
    this.rating,
    this.reviewCount,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String image;
  final double? rating;
  final int? reviewCount;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = FoodImage(image: image, width: 76, height: 76);

    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShape.container),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                thumb,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 13,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(height: 6),
                        RatingBadge(rating!, reviewCount: reviewCount),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 홈 상단 '오늘의 추천' — 화면 끝까지 닿는 히어로. 이 화면의 시그니처 요소다.
/// 목업(cookpilot-netflix-ui.html)의 `.hero` 를 그대로 옮긴 것이라
/// 눈썹 문구 → 큰 제목 → 메타 한 줄 → 버튼 두 개 순서를 유지한다.
class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onStart,
    this.onSave,
    this.saving = false,
    this.favorite,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onSave;

  /// 저장 요청이 도는 동안 버튼을 잠근다.
  final bool saving;

  /// 저장 여부를 화면에서 먼저 뒤집어 보여줄 때 쓴다.
  /// null 이면 레시피가 들고 온 값을 그대로 쓴다.
  final bool? favorite;

  @override
  Widget build(BuildContext context) {
    final servings = recipe.baseServings.toStringAsFixed(
      recipe.baseServings % 1 == 0 ? 0 : 1,
    );
    final saved = favorite ?? recipe.favorite;
    final meta =
        '${recipe.timerMinutes}분 · ${recipe.steps.length}단계 · $servings인분';

    return GestureDetector(
      onTap: onTap,
      // 히어로는 화면 끝까지 간다. 모서리를 둥글리거나 그림자를 주면
      // 가장자리에 카드 테두리가 생겨 꽉 찬 느낌이 깨진다.
      child: ClipRect(
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 사진이 없으면 아이콘 자리표시자 대신 붉은 그라데이션을 깐다.
              // 히어로에 빈 아이콘이 뜨면 로딩 실패처럼 보인다.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE8442B), Color(0xFF8E1F14)],
                  ),
                ),
              ),
              if (recipe.imageUrl.isNotEmpty)
                FoodImage(image: recipe.imageUrl, radius: 0),
              // 하단 텍스트 가독성을 위한 어둠. 위쪽 62%는 건드리지 않는다.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0, 0.62],
                    colors: [Color(0x8C000000), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 추천',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        FilledButton.icon(
                          key: const Key('home-hero-start'),
                          onPressed: onStart ?? onTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            // 테마 기본값이 Size.fromHeight(56) — 폭이 무한이다.
                            // 가로로 늘어놓는 자리라 그대로 두면 레이아웃이 터진다.
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text('요리 시작'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          key: const Key('home-hero-save'),
                          onPressed: saving ? null : onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white10,
                            disabledForegroundColor: Colors.white54,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          icon: Icon(
                            saved ? Icons.bookmark_rounded : Icons.add_rounded,
                            size: 20,
                          ),
                          label: Text(saved ? '저장됨' : '저장'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? AppColors.accent : AppColors.line),
      ),
      child: AnimatedDefaultTextStyle(
        duration: AppMotion.short,
        curve: AppMotion.easeInOut,
        // AnimatedDefaultTextStyle은 테마의 DefaultTextStyle을 대체하므로
        // fontFamily를 명시하지 않으면 한글이 없는 플랫폼 기본 폰트로 떨어진다.
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: selected ? Colors.white : AppColors.slate,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        child: Text(label),
      ),
    );
  }
}

/// 가로 열에 보여 줄 게 없을 때 대신 놓는 자리. 시안의 `.empty-day` —
/// 점선 테두리에 가운데 정렬, 색을 쓰지 않는다. 채워진 카드처럼 보이면
/// 비어 있다는 사실이 묻힌다.
class RailEmptyNote extends StatelessWidget {
  const RailEmptyNote({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final note = CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.muted,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                '$actionLabel →',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (onAction == null) return note;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onAction,
      child: note,
    );
  }
}

/// 점선 테두리. Flutter 의 Border 는 점선을 지원하지 않아 직접 그린다.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final paint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 5, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}

class InfoStrip extends StatelessWidget {
  const InfoStrip({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.wash,
        borderRadius: BorderRadius.circular(AppShape.inner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppColors.slate)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 가로로 넘기는 포스터 카드. 넷플릭스식 홈의 기본 단위다.
///
/// 정사각형으로 잡았다. 세로로 길게 자르면 접시가 잘리고, 가로로 눕히면 한 줄에
/// 두 장밖에 못 넣는다. 요리 사진은 접시가 가운데 오는 구도가 대부분이라 1:1 이 가장 덜 잘린다.
class RecipePosterCard extends StatelessWidget {
  const RecipePosterCard({
    super.key,
    required this.title,
    required this.image,
    this.meta,
    this.badge,
    this.progress,
    this.width = 116,
    this.thumbRatio = defaultThumbRatio,
    required this.onTap,
  });

  /// 카드 사진 비율. 정사각형이다.
  static const defaultThumbRatio = 1.0;

  /// 이어하기 열처럼 가로로 넓은 변형에서 바꿔 준다.
  final double thumbRatio;

  final String title;
  final String image;
  final String? meta;
  final String? badge;

  /// 0~1. 이어서 요리하기 카드에만 쓴다.
  final double? progress;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShape.inner),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 높이를 폭에서 계산하지 않는다. 그리드 셀에서는 폭이 무한으로 들어와
              // (부모가 정해 줌) 곱셈이 무한 높이를 만든다.
              AspectRatio(
                aspectRatio: thumbRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      image: image,
                      width: width.isFinite ? width : null,
                      radius: 12,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x99000000), Color(0x00000000)],
                            stops: [0, 0.55],
                          ),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: progress != null ? 12 : 8,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (progress != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                          child: LinearProgressIndicator(
                            value: progress!.clamp(0, 1),
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (meta != null) ...[
                const SizedBox(height: 6),
                Text(
                  meta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목 한 줄 + 가로 스크롤 카드 묶음.
///
/// 화면 폭 끝까지 카드가 이어져야 "옆에 더 있다"가 보이므로, 목록만 좌우 여백을
/// 갖고 바깥 패딩은 두지 않는다(호출부가 음수 마진을 쓰지 않아도 되게).
class RecipeRail extends StatelessWidget {
  const RecipeRail({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.cardWidth = 116,
    this.thumbRatio = RecipePosterCard.defaultThumbRatio,
    this.hasMeta = false,
  });

  final String title;
  final List<Widget> children;
  final String? trailing;

  /// 카드 폭. 사진 높이는 여기에 비율을 적용해 구한다.
  final double cardWidth;

  /// 카드 사진 비율. 카드에 준 값과 같아야 열 높이가 맞는다.
  final double thumbRatio;

  /// 카드 아래 한 줄짜리 설명이 붙는지. 붙는 만큼만 높이를 더한다.
  final bool hasMeta;

  /// 열 높이는 카드에서 구한다. 고정값을 쓰면 카드보다 커진 만큼
  /// 열 아래에 빈 띠가 생긴다.
  double get _cardHeight =>
      cardWidth / thumbRatio + (hasMeta ? _metaHeight : 0);
  static const _metaHeight = 6 + 10.5 * 1.35;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 열 사이 여백은 좁게 둔다 — 넓으면 한 화면에 한 열밖에 안 들어와
          // 카탈로그가 작아 보인다.
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.zero,
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => children[index],
          ),
        ),
      ],
    );
  }
}
