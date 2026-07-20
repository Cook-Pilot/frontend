import 'package:flutter/material.dart';

import '../../../../design/cookpilot_colors.dart';
import '../../../../design/cookpilot_spacing.dart';
import '../../domain/cooking_session_state.dart';

@immutable
final class VoiceStatusPresentation {
  const VoiceStatusPresentation({
    required this.title,
    required this.description,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
}

final class VoiceStatusBar extends StatelessWidget {
  const VoiceStatusBar({
    required this.phase,
    required this.latestMessage,
    required this.lastRecognizedUtterance,
    this.onOpenAppSettings,
    super.key,
  });

  final VoicePhase phase;
  final String? latestMessage;
  final String? lastRecognizedUtterance;
  final VoidCallback? onOpenAppSettings;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final presentation = _presentationFor(phase);
    final baseDescription = latestMessage ?? presentation.description;
    final recognized = lastRecognizedUtterance;
    final description =
        recognized == null || baseDescription.contains(recognized)
        ? baseDescription
        : '“$recognized”로 들었어요 · $baseDescription';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '${presentation.title}. $description',
      child: AnimatedContainer(
        key: const Key('voice-status-bar'),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutQuart,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(
          horizontal: CookPilotSpacing.lg,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: presentation.background,
          border: Border.symmetric(
            horizontal: BorderSide(color: presentation.border),
          ),
        ),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: presentation.foreground.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    CookPilotSpacing.radiusSm,
                  ),
                ),
                child: Icon(
                  presentation.icon,
                  size: 20,
                  color: presentation.foreground,
                ),
              ),
            ),
            const SizedBox(width: CookPilotSpacing.sm),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      presentation.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: presentation.foreground,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      description,
                      softWrap: true,
                      maxLines: textScale > 1.3 ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: presentation.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (phase == VoicePhase.permissionDenied &&
                onOpenAppSettings != null)
              IconButton(
                key: const Key('open-app-settings'),
                onPressed: onOpenAppSettings,
                tooltip: '앱 설정 열기',
                color: presentation.foreground,
                style: ButtonStyle(
                  shape: const WidgetStatePropertyAll<OutlinedBorder>(
                    CircleBorder(),
                  ),
                  side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                    return states.contains(WidgetState.focused)
                        ? const BorderSide(
                            color: CookPilotColors.semanticWarning,
                            width: 3,
                          )
                        : BorderSide.none;
                  }),
                ),
                icon: const Icon(Icons.settings_outlined),
              )
            else if (phase == VoicePhase.listening && textScale <= 1.3)
              const ExcludeSemantics(child: _StaticWaveform()),
          ],
        ),
      ),
    );
  }

  VoiceStatusPresentation _presentationFor(VoicePhase value) {
    return switch (value) {
      VoicePhase.off => const VoiceStatusPresentation(
        title: '음성 꺼짐',
        description: '버튼으로 계속 조리할 수 있어요.',
        icon: Icons.mic_off_rounded,
        background: CookPilotColors.neutralSurface,
        foreground: CookPilotColors.neutralInk,
        border: CookPilotColors.neutralLine,
      ),
      VoicePhase.permissionDenied => const VoiceStatusPresentation(
        title: '마이크 권한 필요',
        description: '설정에서 허용하거나 버튼을 사용하세요.',
        icon: Icons.no_accounts_rounded,
        background: CookPilotColors.neutralBackground,
        foreground: CookPilotColors.semanticWarning,
        border: CookPilotColors.semanticWarning,
      ),
      VoicePhase.starting => const VoiceStatusPresentation(
        title: '마이크 준비 중',
        description: '준비되면 바로 음성 명령을 들을게요.',
        icon: Icons.settings_voice_rounded,
        background: CookPilotColors.primarySoft,
        foreground: CookPilotColors.primaryActive,
        border: CookPilotColors.primary,
      ),
      VoicePhase.listening => const VoiceStatusPresentation(
        title: '듣는 중',
        description: '말하면 바로 실행해요.',
        icon: Icons.mic_rounded,
        background: CookPilotColors.primary,
        foreground: CookPilotColors.neutralBackground,
        border: CookPilotColors.primary,
      ),
      VoicePhase.recognizing => const VoiceStatusPresentation(
        title: '확인 중',
        description: '말씀하신 내용을 확인하고 있어요.',
        icon: Icons.hearing_rounded,
        background: CookPilotColors.primarySoft,
        foreground: CookPilotColors.primaryActive,
        border: CookPilotColors.primary,
      ),
      VoicePhase.processing => const VoiceStatusPresentation(
        title: '답변 준비 중',
        description: '타이머와 버튼은 계속 사용할 수 있어요.',
        icon: Icons.manage_search_rounded,
        background: CookPilotColors.primarySoft,
        foreground: CookPilotColors.primaryActive,
        border: CookPilotColors.primary,
      ),
      VoicePhase.speaking => const VoiceStatusPresentation(
        title: '안내 중',
        description: '화면에서도 같은 내용을 확인할 수 있어요.',
        icon: Icons.volume_up_rounded,
        background: CookPilotColors.primary,
        foreground: CookPilotColors.neutralBackground,
        border: CookPilotColors.primary,
      ),
      VoicePhase.retryRequired => const VoiceStatusPresentation(
        title: '다시 말해주세요',
        description: '짧게 말하거나 아래 버튼을 눌러주세요.',
        icon: Icons.refresh_rounded,
        background: CookPilotColors.neutralBackground,
        foreground: CookPilotColors.semanticWarning,
        border: CookPilotColors.semanticWarning,
      ),
      VoicePhase.failed => const VoiceStatusPresentation(
        title: '음성을 사용할 수 없어요',
        description: '버튼으로 조리를 계속하세요.',
        icon: Icons.error_outline_rounded,
        background: CookPilotColors.neutralBackground,
        foreground: CookPilotColors.semanticError,
        border: CookPilotColors.semanticError,
      ),
    };
  }
}

final class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform();

  @override
  Widget build(BuildContext context) {
    const heights = <double>[12, 22, 16, 26, 14];
    return SizedBox(
      width: 34,
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: heights
            .map(
              (height) => Container(
                width: 3,
                height: height,
                decoration: BoxDecoration(
                  color: CookPilotColors.neutralBackground,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
