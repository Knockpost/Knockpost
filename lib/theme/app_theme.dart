import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Smooth page transition (Instagram-like fade + slide) ────────────────────

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Incoming page: slides in from slight right + fades
    // Outgoing page: stays COMPLETELY STILL (posts don't move)
    final slide = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }

}

// ─── App Theme ────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static const Color lightPrimary = Color(0xFF000000);
  static const Color darkPrimary  = Color(0xFFFFFFFF);

  static const _transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _SmoothPageTransitionsBuilder(),
      TargetPlatform.iOS:     _SmoothPageTransitionsBuilder(),
    },
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceContainerHighest: Color(0xFFF2F2F2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black),
    ),
    pageTransitionsTheme: _transitions,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      surface: Color(0xFF1A1A1A),
      onSurface: Colors.white,
      surfaceContainerHighest: Color(0xFF2A2A2A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1A1A1A),
      surfaceTintColor: Colors.transparent,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    textTheme: const TextTheme(
      bodyLarge:  TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
    pageTransitionsTheme: _transitions,
  );

  static SystemUiOverlayStyle getSystemUiOverlayStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }
}
