import 'package:flutter/material.dart';

/// Central color palette. Swap values here to retheme the whole app.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B1220);
  static const card = Color(0xFF141B2E);
  static const cardAlt = Color(0xFF1A2338);
  static const border = Color(0xFF243049);

  static const accent = Color(0xFF3ECF8E);
  static const protein = Color(0xFFEC6A87);
  static const carbs = Color(0xFFF5B942);
  static const fat = Color(0xFF4FA8F0);
  static const meal = Color(0xFFE05A5A);
  // Deliberately desaturated relative to accent/protein/carbs/fat — these
  // are secondary metrics on Trends and shouldn't compete for attention
  // with calories/macros when all sections are visible in one scroll.
  static const steps = Color(0xFF8B93A6);
  static const weight = Color(0xFF6B9B96);

  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textMuted = Colors.white38;
}

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  ).copyWith(primary: AppColors.accent, surface: AppColors.card);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
      ),
    ),
  );
}
