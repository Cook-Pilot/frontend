import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';
import '../../domain/cooking_step.dart';

final class StepMedia extends StatefulWidget {
  const StepMedia({required this.step, required this.height, super.key});

  final CookingStep step;
  final double height;

  @override
  State<StepMedia> createState() => _StepMediaState();
}

final class _StepMediaState extends State<StepMedia> {
  bool _mediaFailed = false;

  @override
  void didUpdateWidget(covariant StepMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id ||
        oldWidget.step.mediaAsset != widget.step.mediaAsset) {
      _mediaFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final hasMedia =
        step.mediaType == StepMediaType.image && step.mediaAsset != null;
    final showImage = hasMedia && !_mediaFailed;
    final media = showImage
        ? Image.asset(
            step.mediaAsset!,
            key: ValueKey<String>(step.mediaAsset!),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) {
              _markMediaFailed();
              return _MediaFallback(step: step, mediaUnavailable: true);
            },
          )
        : _MediaFallback(step: step, mediaUnavailable: hasMedia);

    return Semantics(
      container: true,
      label: showImage
          ? '${step.mediaLabel}. ${step.mediaCaption}. 조리 예시 이미지입니다.'
          : hasMedia
          ? '이미지를 불러오지 못했습니다. ${step.completionCue}'
          : '이 단계에는 조리 예시 이미지가 없습니다. 완료 기준: ${step.completionCue}',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('step-media'),
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              media,
              if (showImage)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CookPilotSpacing.md,
                      vertical: CookPilotSpacing.sm,
                    ),
                    color: CookPilotColors.instrumentPanel,
                    child: largeText
                        ? Text(
                            step.mediaCaption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: CookPilotColors.neutralBackground,
                                ),
                          )
                        : Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  step.mediaCaption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color:
                                            CookPilotColors.neutralBackground,
                                      ),
                                ),
                              ),
                              const SizedBox(width: CookPilotSpacing.sm),
                              Text(
                                '조리 예시',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: CookPilotColors.instrumentMuted,
                                    ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _markMediaFailed() {
    if (_mediaFailed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_mediaFailed) {
        setState(() => _mediaFailed = true);
      }
    });
  }
}

final class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.step, required this.mediaUnavailable});

  final CookingStep step;
  final bool mediaUnavailable;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return ColoredBox(
      color: CookPilotColors.neutralSurfaceActive,
      child: Padding(
        padding: const EdgeInsets.all(CookPilotSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(
              mediaUnavailable
                  ? Icons.image_not_supported_outlined
                  : Icons.fact_check_outlined,
              size: 24,
              color: CookPilotColors.neutralMuted,
            ),
            const SizedBox(width: CookPilotSpacing.sm),
            Expanded(
              child: Text(
                mediaUnavailable
                    ? '이미지를 불러오지 못했어요. ${step.completionCue}'
                    : '완료 기준: ${step.completionCue}',
                maxLines: largeText ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
