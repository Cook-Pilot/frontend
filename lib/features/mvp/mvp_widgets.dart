import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../recipe/domain/recipe.dart';

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

class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.children,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.accentHeader = false,
  });

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
              title: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            24,
          ),
          children: children,
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

/// 홈 상단 '오늘의 메뉴' — 풀블리드 이미지 위에 그라데이션과 텍스트를 얹은
/// 몰입형 히어로 카드. 이 화면의 시그니처 요소.
class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({super.key, required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppShape.container),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppShape.container),
            child: AspectRatio(
              aspectRatio: 16 / 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodImage(image: recipe.imageUrl, radius: 0),
                  // 하단 텍스트 가독성을 위한 딥브라운 그라데이션.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.45, 1],
                        colors: [Colors.transparent, Color(0xCC1F1209)],
                      ),
                    ),
                  ),
                  if (recipe.badge != null)
                    Positioned(
                      left: 14,
                      top: 14,
                      child: ImageLabelChip(recipe.badge!),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: Colors.white70,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.timerMinutes}분 타이머',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Colors.white70,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.baseServings.toStringAsFixed(recipe.baseServings % 1 == 0 ? 0 : 1)}인분',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
/// 세로 3:4 로 잡았다. 영화 포스터는 2:3 이 표준이지만 음식 사진은 가로가 표준이라,
/// 그대로 세로로 길게 자르면 음식이 잘린다.
class RecipePosterCard extends StatelessWidget {
  const RecipePosterCard({
    super.key,
    required this.title,
    required this.image,
    this.meta,
    this.badge,
    this.progress,
    this.width = 116,
    required this.onTap,
  });

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
                aspectRatio: 3 / 4,
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
                  maxLines: 2,
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
    this.cardHeight = 210,
  });

  final String title;
  final List<Widget> children;
  final String? trailing;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
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
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
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
