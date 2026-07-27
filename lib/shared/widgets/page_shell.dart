import 'package:cookpilot/app/app_theme.dart';
import 'package:flutter/material.dart';

/// 목록형 화면의 공통 뼈대. 좌우 여백/바닥 버튼 배치를 통일한다.
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
    final horizontalPadding =
        MediaQuery.of(context).size.width < 390 ? 16.0 : 20.0;

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
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

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? AppColors.ink : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.slate,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onTap == null) return pill;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: pill,
    );
  }
}
