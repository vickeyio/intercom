import 'package:flutter/material.dart';

/// Cinematic dark theme constants — used across all screens.
class AppColors {
  AppColors._();

  static const Color background  = Color(0xFF0D0F14); // deep charcoal
  static const Color surface     = Color(0xFF141720); // card surface
  static const Color orange      = Color(0xFFFF7A1E); // director / active
  static const Color orangeDark  = Color(0xFFC94F00); // gradient end
  static const Color blue        = Color(0xFF3C96FF); // crew / listening
  static const Color textPrimary = Color(0xFFFFFFFF);

  static Color get textMuted     => Colors.white.withValues(alpha: 0.4);
  static Color get border        => Colors.white.withValues(alpha: 0.08);
  static Color get borderStrong  => Colors.white.withValues(alpha: 0.12);
  static Color get surfaceInput  => Colors.white.withValues(alpha: 0.06);
}

class AppTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.blue,
        surface: AppColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
