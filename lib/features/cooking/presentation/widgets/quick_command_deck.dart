import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';

final class QuickCommandDeck extends StatelessWidget {
  const QuickCommandDeck({
    required this.onPrevious,
    required this.onRepeat,
    required this.onAddMinute,
    required this.onNext,
    super.key,
  });

  final VoidCallback? onPrevious;
  final VoidCallback onRepeat;
  final VoidCallback onAddMinute;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = textScale > 1.3;
        final actionHeight = textScale > 1.6
            ? 88.0
            : textScale > 1.3
            ? 74.0
            : CookPilotSpacing.quickActionHeight;
        final actions = <Widget>[
          _QuickAction(
            key: const Key('previous-step'),
            label: '이전',
            semanticLabel: '이전 단계',
            icon: Icons.chevron_left_rounded,
            onPressed: onPrevious,
          ),
          _QuickAction(
            key: const Key('repeat-instruction'),
            label: '다시 듣기',
            semanticLabel: '현재 안내 다시 듣기',
            icon: Icons.replay_rounded,
            onPressed: onRepeat,
          ),
          _QuickAction(
            key: const Key('add-minute'),
            label: '1분 추가',
            semanticLabel: '타이머에 1분 추가',
            icon: Icons.add_circle_outline_rounded,
            onPressed: onAddMinute,
          ),
          _QuickAction(
            key: const Key('next-step'),
            label: '다음',
            semanticLabel: '다음 단계',
            icon: Icons.chevron_right_rounded,
            onPressed: onNext,
            primary: true,
          ),
        ];

        if (useGrid) {
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: CookPilotSpacing.sm,
            crossAxisSpacing: CookPilotSpacing.sm,
            mainAxisExtent: actionHeight,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: actions,
          );
        }

        return Row(
          children: <Widget>[
            for (var index = 0; index < actions.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: CookPilotSpacing.sm),
              Expanded(child: actions[index]),
            ],
          ],
        );
      },
    );
  }
}

final class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(height: CookPilotSpacing.xs),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(0, CookPilotSpacing.quickActionHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CookPilotSpacing.radiusMd),
        ),
      ),
    );

    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, CookPilotSpacing.quickActionHeight),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CookPilotSpacing.radiusMd),
          ),
          backgroundColor: CookPilotColors.primary,
          foregroundColor: CookPilotColors.neutralBackground,
          disabledBackgroundColor: CookPilotColors.neutralSurfaceActive,
          disabledForegroundColor: CookPilotColors.neutralMuted,
        ),
        child: child,
      );
    }
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}
