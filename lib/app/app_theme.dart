import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const ink = Color(0xFF111827);
  static const slate = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const surface = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const accent = Color(0xFFFACC15);
  static const success = Color(0xFF16A34A);
}

/// Shared easing curves and durations, tuned per the "ease-out for entering,
/// ease-in-out for on-screen movement" rule of thumb. Keep every ad-hoc
/// animation in the app pulling from here so motion feels like one system.
class AppMotion {
  const AppMotion._();

  /// Entering / exiting elements. Starts fast, feels responsive.
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Elements moving or morphing on screen (progress bars, step swaps).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  static const fast = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 260);
  static const long = Duration(milliseconds: 400);
}

class _CookPilotPageTransitionsBuilder extends PageTransitionsBuilder {
  const _CookPilotPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }

    final curved = CurvedAnimation(parent: animation, curve: AppMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

ThemeData buildCookPilotTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.ink,
    primary: AppColors.ink,
    secondary: AppColors.accent,
    surface: Colors.white,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surface,
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _CookPilotPageTransitionsBuilder(),
        TargetPlatform.iOS: _CookPilotPageTransitionsBuilder(),
      },
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
      ),
    ),
  );
}
