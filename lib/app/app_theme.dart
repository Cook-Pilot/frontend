import 'package:flutter/material.dart';

/// "따뜻한 키친" 팔레트.
/// 순검정·순백·차가운 회색을 쓰지 않고, 크림 바탕 위에 에스프레소 브라운과
/// 파프리카 포인트 하나로 통일한다. 회색 계열은 전부 웜 톤으로 맞춘다.
class AppColors {
  const AppColors._();

  /// 본문·제목 텍스트. 순검정 대신 깊은 에스프레소 브라운.
  static const ink = Color(0xFF33261A);

  /// 보조 텍스트.
  static const slate = Color(0xFF7A6A58);

  /// 힌트·비활성 텍스트.
  static const muted = Color(0xFFA8988A);

  /// 앱 배경. 크림 아이보리.
  static const surface = Color(0xFFFAF5EE);

  /// 카드 표면.
  static const card = Color(0xFFFFFFFF);

  /// 헤어라인·테두리.
  static const line = Color(0xFFEFE5D8);

  /// 브랜드 포인트. 파프리카(테라코타 오렌지).
  static const accent = Color(0xFFD4572E);

  /// 포인트의 연한 배경 버전(선택 상태, 강조 스트립).
  static const accentSoft = Color(0xFFF9E8DD);

  /// 정보 스트립 등 은은한 웜 배경.
  static const wash = Color(0xFFF5EDE2);

  /// 카카오 로그인 버튼 전용 브랜드 컬러.
  static const kakao = Color(0xFFFEE500);

  /// 완료·성공. 허브 그린.
  static const success = Color(0xFF5C8A4E);

  /// 그림자. 브라운 틴트를 섞어 배경과 어우러지게.
  static const shadow = Color(0x1F8A6A45);
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

/// 형태 토큰. 컨테이너는 20, 내부 요소는 14로 이원화해 위계를 만든다.
class AppShape {
  const AppShape._();

  static const container = 20.0;
  static const inner = 14.0;
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
    // 화면 전환 애니메이션 없이 즉시 전환한다. 저사양 기기에서 전환·진입
    // 애니메이션이 겹치며 씹히는 문제로 장식용 모션은 전부 걷어냈다.
    return child;
  }
}

ThemeData buildCookPilotTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    secondary: AppColors.ink,
    surface: AppColors.card,
  );

  const displayStyle = TextStyle(
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
    color: AppColors.ink,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surface,
    useMaterial3: true,
    fontFamily: 'Pretendard',
    textTheme: TextTheme(
      headlineLarge: displayStyle.copyWith(fontSize: 32),
      headlineMedium: displayStyle.copyWith(fontSize: 28),
      headlineSmall: displayStyle.copyWith(fontSize: 23),
      titleLarge: displayStyle.copyWith(fontSize: 20, letterSpacing: -0.4),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: AppColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: AppColors.ink,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    ),
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
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 3,
      shadowColor: AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.container),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.line, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.slate,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.muted),
      labelStyle: const TextStyle(color: AppColors.slate),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inner),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inner),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inner),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.accentSoft,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.shadow,
      elevation: 3,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.muted,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.wash,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent
            : Colors.transparent,
      ),
      side: const BorderSide(color: AppColors.muted, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.ink),
    ),
  );
}
