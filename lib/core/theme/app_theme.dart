import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF8B4A00);
  static const surface = Color(0xFFF3F5FF);
  static const critical = Color(0xFFB3261E);
  static const warning = Color(0xFFE08A00);
  static const success = Color(0xFF2E7D32);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
    );