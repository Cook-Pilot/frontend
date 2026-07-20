import 'package:flutter/material.dart';

import 'cookpilot_colors.dart';
import 'cookpilot_spacing.dart';
import 'cookpilot_theme_extensions.dart';

abstract final class CookPilotTheme {
  static const _fontFallback = <String>[
    'Apple SD Gothic Neo',
    'Noto Sans KR',
    'sans-serif',
  ];

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: CookPilotColors.primary,
      onPrimary: CookPilotColors.neutralBackground,
      primaryContainer: CookPilotColors.primarySoft,
      onPrimaryContainer: CookPilotColors.primaryActive,
      secondary: CookPilotColors.neutralMuted,
      onSecondary: CookPilotColors.neutralBackground,
      surface: CookPilotColors.neutralBackground,
      onSurface: CookPilotColors.neutralInk,
      onSurfaceVariant: CookPilotColors.neutralMuted,
      surfaceContainer: CookPilotColors.neutralSurface,
      surfaceContainerHigh: CookPilotColors.neutralSurfaceActive,
      outline: CookPilotColors.neutralLine,
      error: CookPilotColors.semanticError,
      onError: CookPilotColors.neutralBackground,
      inverseSurface: CookPilotColors.instrumentPanel,
      onInverseSurface: CookPilotColors.neutralBackground,
      inversePrimary: CookPilotColors.progress,
      shadow: Colors.transparent,
      scrim: Color(0x9904070E),
    );

    final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: CookPilotColors.neutralBackground,
      dividerColor: CookPilotColors.neutralLine,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: _textTheme,
      extensions: const <ThemeExtension<dynamic>>[
        CookPilotSemanticColors.light,
      ],
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              elevation: 0,
              minimumSize: const Size(
                CookPilotSpacing.minimumTapTarget,
                CookPilotSpacing.minimumTapTarget,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CookPilotSpacing.radiusMd),
              ),
              textStyle: _textTheme.labelLarge,
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                return states.contains(WidgetState.focused)
                    ? const BorderSide(
                        color: CookPilotColors.neutralBackground,
                        width: 3,
                      )
                    : BorderSide.none;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: CookPilotColors.neutralInk,
              minimumSize: const Size(
                CookPilotSpacing.minimumTapTarget,
                CookPilotSpacing.minimumTapTarget,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CookPilotSpacing.radiusMd),
              ),
              textStyle: _textTheme.labelLarge,
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                return states.contains(WidgetState.focused)
                    ? const BorderSide(
                        color: CookPilotColors.semanticWarning,
                        width: 3,
                      )
                    : const BorderSide(color: CookPilotColors.neutralMuted);
              }),
            ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: CookPilotColors.neutralBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CookPilotSpacing.radiusLg),
          side: const BorderSide(color: CookPilotColors.neutralLine),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CookPilotColors.instrumentPanel,
        contentTextStyle: TextStyle(
          color: CookPilotColors.neutralBackground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamilyFallback: _fontFallback,
        ),
      ),
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
      color: CookPilotColors.neutralInk,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 54,
      fontWeight: FontWeight.w700,
      height: 0.98,
      letterSpacing: -1.89,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    headlineSmall: TextStyle(
      color: CookPilotColors.neutralInk,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 27,
      fontWeight: FontWeight.w700,
      height: 1.21,
      letterSpacing: -0.81,
    ),
    titleMedium: TextStyle(
      color: CookPilotColors.neutralInk,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 15,
      fontWeight: FontWeight.w800,
      height: 1.25,
      letterSpacing: -0.15,
    ),
    titleSmall: TextStyle(
      color: CookPilotColors.neutralInk,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.18,
      letterSpacing: -0.14,
    ),
    bodyMedium: TextStyle(
      color: CookPilotColors.neutralMuted,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      color: CookPilotColors.neutralInk,
      fontFamily: 'Pretendard',
      fontFamilyFallback: _fontFallback,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
  );
}
