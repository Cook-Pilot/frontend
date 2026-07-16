import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import 'mock_data.dart';

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

/// Fades and slides a child in shortly after [delay], for staggering list
/// entrances (~30-80ms apart) so a screen feels like it arrives, not just
/// appears. Purely decorative: never gates interaction.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.medium);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easeOut,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
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
  });

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
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class FoodTile extends StatelessWidget {
  const FoodTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.heroTag,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShape.container),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                heroTag == null
                    ? const FoodPreview(size: 58)
                    : Hero(tag: heroTag!, child: const FoodPreview(size: 58)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.slate),
                      ),
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

class FoodPreview extends StatelessWidget {
  const FoodPreview({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size.isFinite ? size : double.infinity;
    final height = size.isFinite ? size : 138.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBEBD9), Color(0xFFF3D8BC)],
        ),
        borderRadius: BorderRadius.circular(AppShape.inner),
      ),
      child: Icon(
        Icons.restaurant_rounded,
        color: const Color(0xFFC08A5A),
        size: height * 0.34,
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        child: Text(label),
      ),
    );
  }
}

class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({super.key, required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShape.container),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'recipe-image-${recipe.title}',
                  child: const FoodPreview(size: double.infinity),
                ),
                const SizedBox(height: 14),
                Text(
                  recipe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recipe.minutes}분 · ${recipe.difficulty} · 2인분 · ★ ${recipe.rating}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.slate),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recipe.tags.map((tag) => Pill(tag)).toList(),
                ),
              ],
            ),
          ),
        ),
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
                    fontWeight: FontWeight.w800,
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
