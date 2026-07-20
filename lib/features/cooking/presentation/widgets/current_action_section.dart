import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';
import '../../domain/cooking_step.dart';

final class CurrentActionSection extends StatelessWidget {
  const CurrentActionSection({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.compact,
    super.key,
  });

  final CookingStep step;
  final int stepIndex;
  final int stepCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = (stepIndex + 1) / stepCount;
    final headline = textTheme.headlineSmall?.copyWith(
      fontSize: compact ? 24 : 27,
    );

    return Semantics(
      container: true,
      label:
          '현재 ${stepIndex + 1}단계. ${step.instruction} 완료 기준. ${step.completionCue}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            CookPilotSpacing.xl,
            compact ? 10 : 14,
            CookPilotSpacing.xl,
            compact ? 9 : 13,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '현재 단계',
                    style: textTheme.bodyMedium?.copyWith(
                      color: CookPilotColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 70,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: CookPilotColors.neutralLine,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        CookPilotColors.primary,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CookPilotSpacing.sm),
              Text(
                step.instruction,
                key: const Key('current-action'),
                softWrap: true,
                style: headline,
              ),
              const SizedBox(height: CookPilotSpacing.xs),
              Text(
                step.completionCue,
                key: const Key('completion-cue'),
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
