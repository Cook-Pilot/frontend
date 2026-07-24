import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';

final class CookingTopBar extends StatelessWidget {
  const CookingTopBar({
    required this.recipeName,
    required this.currentStep,
    required this.stepCount,
    super.key,
  });

  final String recipeName;
  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CookPilotSpacing.lg,
          vertical: CookPilotSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: CookPilotColors.primary,
                borderRadius: BorderRadius.circular(CookPilotSpacing.radiusXs),
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                size: 15,
                color: CookPilotColors.neutralBackground,
              ),
            ),
            const SizedBox(width: CookPilotSpacing.sm),
            Flexible(
              child: Text(
                'CookPilot',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: CookPilotSpacing.sm),
            Expanded(
              child: Semantics(
                label: '$recipeName, 전체 $stepCount단계 중 $currentStep단계',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        recipeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.titleSmall,
                      ),
                      Text(
                        '$currentStep / $stepCount 단계',
                        maxLines: 1,
                        style: textTheme.labelLarge?.copyWith(
                          color: CookPilotColors.neutralMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
