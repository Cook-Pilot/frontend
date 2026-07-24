import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';
import '../../domain/cooking_session_state.dart';

final class TimerInstrument extends StatelessWidget {
  const TimerInstrument({
    required this.remaining,
    required this.progress,
    required this.status,
    required this.compact,
    required this.onToggle,
    super.key,
  });

  final Duration remaining;
  final double progress;
  final TimerStatus status;
  final bool compact;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale > 1.3;
    final dialSize = compact ? 58.0 : 72.0;
    final nominalTimeSize = compact || largeText ? 45.0 : 54.0;
    final timeStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      color: CookPilotColors.neutralBackground,
      fontSize: nominalTimeSize,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final statusLabel = switch (status) {
      TimerStatus.idle => '타이머 없음',
      TimerStatus.running => '진행 중',
      TimerStatus.paused => '일시정지',
      TimerStatus.elapsed => '시간 종료',
    };
    final semanticTime = _semanticDuration(remaining);
    final toggleLabel = status == TimerStatus.running
        ? '타이머 일시정지'
        : status == TimerStatus.paused
        ? '타이머 계속'
        : null;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '남은 시간 $semanticTime, $statusLabel',
      child: Container(
        key: const Key('timer-instrument'),
        constraints: BoxConstraints(minHeight: compact ? 88 : 105),
        padding: EdgeInsets.symmetric(
          horizontal: CookPilotSpacing.xl,
          vertical: compact ? 7 : 10,
        ),
        color: CookPilotColors.instrumentPanel,
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text('남은 시간', style: _metaStyle(context)),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Text(
                          statusLabel,
                          style: _statusStyle(context, status),
                        ),
                      ),
                      if (toggleLabel != null) ...<Widget>[
                        const SizedBox(width: CookPilotSpacing.xs),
                        _TimerToggleButton(
                          status: status,
                          onToggle: onToggle!,
                          tooltip: toggleLabel,
                        ),
                      ],
                    ],
                  ),
                  ExcludeSemantics(
                    child: Text(
                      _displayDuration(remaining),
                      key: const Key('remaining-time'),
                      maxLines: 1,
                      style: timeStyle,
                    ),
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  SizedBox.square(
                    dimension: dialSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CustomPaint(
                          size: Size.square(dialSize),
                          painter: _TimerRingPainter(progress: progress),
                        ),
                        if (toggleLabel != null)
                          _TimerToggleButton(
                            status: status,
                            onToggle: onToggle!,
                            tooltip: toggleLabel,
                          )
                        else
                          Icon(
                            status == TimerStatus.elapsed
                                ? Icons.notifications_active_outlined
                                : Icons.timer_off_outlined,
                            size: 20,
                            color: status == TimerStatus.elapsed
                                ? CookPilotColors.focus
                                : CookPilotColors.instrumentMuted,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '남은 시간',
                                  style: _metaStyle(context),
                                ),
                              ),
                              Text(
                                statusLabel,
                                style: _statusStyle(context, status),
                              ),
                            ],
                          ),
                          Text(
                            _displayDuration(remaining),
                            key: const Key('remaining-time'),
                            maxLines: 1,
                            style: timeStyle,
                          ),
                          Text(
                            '“다음”, “다시 말해줘”, “1분 더”라고 말해보세요.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: CookPilotColors.instrumentMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  TextStyle? _metaStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: CookPilotColors.instrumentMuted);
  }

  TextStyle? _statusStyle(BuildContext context, TimerStatus value) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      color: value == TimerStatus.elapsed
          ? CookPilotColors.focus
          : CookPilotColors.progress,
    );
  }

  static String _displayDuration(Duration duration) {
    final totalSeconds = (duration.inMilliseconds / 1000)
        .ceil()
        .clamp(0, 5999)
        .toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String _semanticDuration(Duration duration) {
    final totalSeconds = (duration.inMilliseconds / 1000)
        .ceil()
        .clamp(0, 5999)
        .toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) {
      return '$seconds초';
    }
    return '$minutes분 $seconds초';
  }
}

final class _TimerToggleButton extends StatelessWidget {
  const _TimerToggleButton({
    required this.status,
    required this.onToggle,
    required this.tooltip,
  });

  final TimerStatus status;
  final VoidCallback onToggle;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: CookPilotSpacing.minimumTapTarget,
      child: IconButton(
        key: const Key('timer-toggle'),
        onPressed: onToggle,
        tooltip: tooltip,
        color: CookPilotColors.neutralBackground,
        iconSize: 20,
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
          side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
            return states.contains(WidgetState.focused)
                ? const BorderSide(color: CookPilotColors.focus, width: 3)
                : BorderSide.none;
          }),
        ),
        icon: Icon(
          status == TimerStatus.running
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
        ),
      ),
    );
  }
}

final class _TimerRingPainter extends CustomPainter {
  const _TimerRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 8) / 2;
    final track = Paint()
      ..color = CookPilotColors.instrumentLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final value = Paint()
      ..color = CookPilotColors.progress
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        value,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
