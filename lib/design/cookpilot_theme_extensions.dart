import 'package:flutter/material.dart';

import 'cookpilot_colors.dart';

@immutable
final class CookPilotSemanticColors
    extends ThemeExtension<CookPilotSemanticColors> {
  const CookPilotSemanticColors({
    required this.success,
    required this.warning,
    required this.focus,
    required this.instrumentMuted,
    required this.instrumentLine,
    required this.primaryHover,
    required this.primaryActive,
  });

  static const light = CookPilotSemanticColors(
    success: CookPilotColors.semanticSuccess,
    warning: CookPilotColors.semanticWarning,
    focus: CookPilotColors.focus,
    instrumentMuted: CookPilotColors.instrumentMuted,
    instrumentLine: CookPilotColors.instrumentLine,
    primaryHover: CookPilotColors.primaryHover,
    primaryActive: CookPilotColors.primaryActive,
  );

  final Color success;
  final Color warning;
  final Color focus;
  final Color instrumentMuted;
  final Color instrumentLine;
  final Color primaryHover;
  final Color primaryActive;

  @override
  CookPilotSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? focus,
    Color? instrumentMuted,
    Color? instrumentLine,
    Color? primaryHover,
    Color? primaryActive,
  }) {
    return CookPilotSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      focus: focus ?? this.focus,
      instrumentMuted: instrumentMuted ?? this.instrumentMuted,
      instrumentLine: instrumentLine ?? this.instrumentLine,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryActive: primaryActive ?? this.primaryActive,
    );
  }

  @override
  CookPilotSemanticColors lerp(
    covariant ThemeExtension<CookPilotSemanticColors>? other,
    double t,
  ) {
    if (other is! CookPilotSemanticColors) {
      return this;
    }
    return CookPilotSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      instrumentMuted: Color.lerp(instrumentMuted, other.instrumentMuted, t)!,
      instrumentLine: Color.lerp(instrumentLine, other.instrumentLine, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryActive: Color.lerp(primaryActive, other.primaryActive, t)!,
    );
  }
}
