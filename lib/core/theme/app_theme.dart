import 'package:flutter/material.dart';

/// Modern Techno Design System
/// Precision engineering aesthetic: cool slate canvas, electric precision blue,
/// crisp telemetry accents, and clean micro-radii.
class AppColors {
  // Primary Precision Tech Blue (Electric / Cyber-Cobalt)
  static const primary = Color(0xFF0284C7);
  static const primaryDark = Color(0xFF0369A1);
  static const primaryLight = Color(0xFF38BDF8);

  // Cool Technical Canvas & Surfaces (Tailwind Slate scale)
  static const surface = Color(0xFFF8FAFC); // Slate-50 Canvas
  static const surfaceContainer = Color(0xFFF1F5F9); // Slate-100 Container
  static const cardBackground = Color(0xFFFFFFFF); // Pure Crisp Card
  static const headerBackground = Color(0xFF0F172A); // Slate-900 High-Tech Header

  // Typography & Text
  static const textPrimary = Color(0xFF0F172A); // Slate-900 Sharp Text
  static const textSecondary = Color(0xFF475569); // Slate-600 Subtext
  static const border = Color(0xFFE2E8F0); // Slate-200 Precision Hairline

  // High-Visibility Telemetry Indicators
  static const critical = Color(0xFFDC2626); // Alert Crimson / Hazard Red
  static const warning = Color(0xFFD97706); // Telemetry Amber
  static const success = Color(0xFF059669); // Nominal Emerald
}

ThemeData buildTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surface,

    // High-Tech Slate AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.headerBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),

    // Clean, Flat Techno Cards with 1px Precision Border
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),

    // Sharp, Modern Action Buttons (no heavy skeuomorphic shadows)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Modern Form Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(
        color: AppColors.textSecondary.withValues(alpha: 0.6),
        fontSize: 14,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.headerBackground,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}