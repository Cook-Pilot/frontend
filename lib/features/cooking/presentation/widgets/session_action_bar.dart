import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';

final class SessionActionBar extends StatelessWidget {
  const SessionActionBar({
    required this.onAbort,
    required this.onComplete,
    super.key,
  });

  final VoidCallback onAbort;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final sessionStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(0, CookPilotSpacing.sessionActionHeight),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CookPilotSpacing.radiusSm),
        ),
      ),
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            key: const Key('abort-session'),
            onPressed: onAbort,
            style: sessionStyle,
            child: const Text('조리 중단'),
          ),
        ),
        const SizedBox(width: CookPilotSpacing.sm),
        Expanded(
          child: FilledButton(
            key: const Key('complete-session'),
            onPressed: onComplete,
            style: sessionStyle.copyWith(
              backgroundColor: const WidgetStatePropertyAll<Color>(
                CookPilotColors.primarySoft,
              ),
              foregroundColor: const WidgetStatePropertyAll<Color>(
                CookPilotColors.primaryActive,
              ),
              side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                return states.contains(WidgetState.focused)
                    ? const BorderSide(
                        color: CookPilotColors.primaryActive,
                        width: 3,
                      )
                    : const BorderSide(color: CookPilotColors.primary);
              }),
            ),
            child: const Text('조리 완료'),
          ),
        ),
      ],
    );
  }
}
