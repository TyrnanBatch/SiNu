import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Central color palette. Surface/text tokens flip with [ThemeController];
/// data/brand colors (accent, macros, steps, weight) stay constant across
/// modes so charts and legends stay recognizable either way.
class AppColors {
  AppColors._();

  static bool get _dark => ThemeController.instance.isDark;

  static Color get background => _dark ? const Color(0xFF0B1220) : const Color(0xFFF5F6F8);
  static Color get card => _dark ? const Color(0xFF141B2E) : Colors.white;
  static Color get cardAlt => _dark ? const Color(0xFF1A2338) : const Color(0xFFEEF0F4);
  static Color get border => _dark ? const Color(0xFF243049) : const Color(0xFFDCE1E8);

  /// Subtle fill for progress-bar/track backgrounds and dashed reference
  /// lines — a sunken look on dark, a recessed one on light.
  static Color get track => _dark ? Colors.white12 : const Color(0x14000000);
  static Color get trackFaint => _dark ? Colors.white10 : const Color(0x0A000000);

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

  static Color get textPrimary => _dark ? Colors.white : const Color(0xFF14181F);
  static Color get textSecondary => _dark ? Colors.white70 : const Color(0xFF4B5566);
  static Color get textMuted => _dark ? Colors.white38 : const Color(0xFF8A94A3);
}

ThemeData buildAppTheme() {
  final brightness = ThemeController.instance.isDark ? Brightness.dark : Brightness.light;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(primary: AppColors.accent, surface: AppColors.card);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: base,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
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
