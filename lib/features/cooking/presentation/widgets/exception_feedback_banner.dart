import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';

final class ExceptionFeedbackBanner extends StatelessWidget {
  const ExceptionFeedbackBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '예외 상황 안내. $message',
      child: Container(
        key: const Key('exception-feedback'),
        width: double.infinity,
        padding: const EdgeInsets.all(CookPilotSpacing.md),
        decoration: const BoxDecoration(
          color: CookPilotColors.neutralSurface,
          border: Border(
            top: BorderSide(color: CookPilotColors.neutralLine),
            bottom: BorderSide(color: CookPilotColors.neutralLine),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.shield_outlined,
              size: 22,
              color: CookPilotColors.primaryActive,
            ),
            const SizedBox(width: CookPilotSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '지금 할 일',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CookPilotColors.primaryActive,
                    ),
                  ),
                  const SizedBox(height: CookPilotSpacing.xs),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
