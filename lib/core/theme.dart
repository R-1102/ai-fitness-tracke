import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// "Clarity" design tokens — keep in sync with the design canvas.
abstract final class AppColors {
  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF0E1B2C); // primary text + navy cards
  static const muted = Color(0xFF5B6676); // secondary text (5.6:1 on background)
  static const subtle = Color(0xFF9AA4B2); // chevrons, disabled
  static const border = Color(0xFFE4E8EF);
  static const divider = Color(0xFFEEF1F6);
  static const track = Color(0xFFE9EDF3); // segmented control background

  static const accent = Color(0xFF2F6BFF);
  static const accentDark = Color(0xFF1F4FD1);
  static const accentSoft = Color(0xFFE8EEFF);
  static const accentTextOnSoft = Color(0xFF1D2F57);

  static const warn = Color(0xFFD9480F); // wrong reps / form issues
  static const warnSoft = Color(0xFFFFF0E6);
  static const danger = Color(0xFFB5360A);

  static const success = Color(0xFF0E7C55);
  static const successSoft = Color(0xFFE3F5EC);
  static const successText = Color(0xFF0E5C40);
  static const live = Color(0xFF0E9F6E);

  static const navyTrack = Color(0xFF24344B);
  static const onNavyMuted = Color(0xFFA9B6C8);
  static const avatarBg = Color(0xFFDCE6FF);
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const sheet = 28.0;
}

const kFont = 'PlusJakartaSans';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    onPrimary: Colors.white,
    secondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.warn,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kFont);
  TextStyle? w(TextStyle? s, FontWeight weight, {double? spacing}) =>
      s?.copyWith(fontWeight: weight, color: AppColors.ink, letterSpacing: spacing);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.copyWith(
      displaySmall: w(base.textTheme.displaySmall, FontWeight.w800, spacing: -1),
      headlineMedium: w(base.textTheme.headlineMedium, FontWeight.w800, spacing: -0.5),
      headlineSmall: w(base.textTheme.headlineSmall, FontWeight.w800, spacing: -0.5),
      titleLarge: w(base.textTheme.titleLarge, FontWeight.w800),
      titleMedium: w(base.textTheme.titleMedium, FontWeight.w700),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.ink),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(fontFamily: kFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(fontFamily: kFont, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.subtle),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.warn),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w600, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent : const Color(0xFFD8DDE5),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );

}
