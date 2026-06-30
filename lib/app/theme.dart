import "package:flutter/material.dart";

abstract final class AppColors {
  static const accentPurple = Color(0xFF9146FF);
  static const accentPink = Color(0xFFAB47BC);
  static const liveRed = Color(0xFFF44336);
  static const darkBackground = Colors.black;
  static const darkSurface = Color(0xFF1D1B20);
  static const darkControl = Color(0xFF1D1B20);
  static const lightBackground = Color(0xFFF8F8F8);
  static const ink = Color(0xFF1D1B20);
}

ThemeData buildFlowTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accentPurple,
    brightness: brightness,
  );
  final backgroundColor = brightness == Brightness.dark
      ? AppColors.darkBackground
      : AppColors.lightBackground;
  final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.5);
  const borderRadius = BorderRadius.all(Radius.circular(12));
  const borderWidth = 0.5;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: "Inter",
    scaffoldBackgroundColor: backgroundColor,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.3),
      selectionHandleColor: colorScheme.primary,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      titleSpacing: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundColor,
      surfaceTintColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: borderColor),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _InstantPredictiveBackPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.normal,
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(100)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(100)),
        borderSide: BorderSide.none,
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(100)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(100)),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 2),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: borderColor),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: backgroundColor,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      indicatorColor: Colors.transparent,
      indicatorShape: const CircleBorder(),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tooltipTheme: TooltipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      showDuration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      textStyle: TextStyle(color: colorScheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      showCloseIcon: true,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: borderRadius,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      thickness: borderWidth,
      space: borderWidth,
      color: borderColor,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.011,
        height: 1.5,
      ),
      subtitleTextStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 13,
        height: 1.4,
      ),
      leadingAndTrailingTextStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    ),
    textTheme:
        const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.019,
          ),
          titleLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.019,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.011,
          ),
          titleSmall: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.011,
          ),
          labelLarge: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.006,
          ),
          labelMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0),
          labelSmall: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.005,
          ),
          bodyLarge: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.011,
          ),
          bodyMedium: TextStyle(letterSpacing: -0.006),
          bodySmall: TextStyle(letterSpacing: 0),
        ).apply(
          fontFamily: "Inter",
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
  );
}

class _InstantPredictiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPredictiveBackPageTransitionsBuilder();

  static const _predictiveBackBuilder = PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _predictiveBackBuilder.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _predictiveBackBuilder.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}
