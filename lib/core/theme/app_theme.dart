import 'package:flutter/material.dart';

/// Modern Techno Design System — "Light-Dark" Telemetry Edition
/// High-precision engineering aesthetic:
/// - Comfortable, soft dark slate-graphite canvas ("light-dark", avoids harsh pure OLED black)
/// - Vibrant Cyber-Mint / Pulse-Emerald primary (zero blue, high-visibility telemetry)
/// - Clean hairline borders and crisp typography
class AppColors {
  // Primary: Pulse Cyber Mint (Zero Blue)
  static const primary = Color(0xFF00DC82); // Vibrant Electric Mint
  static const primaryDark = Color(0xFF059669);
  static const primaryLight = Color(0xFF34D399);
  static const onPrimary = Color(0xFF022614); // Deep pine for high-contrast button labels

  // Soft "Light-Dark" Charcoal & Slate Canvas
  static const surface = Color(0xFF12161F); // Soft dark graphite canvas (non-glare)
  static const surfaceContainer = Color(0xFF1A202C); // Elevated container / input fill
  static const cardBackground = Color(0xFF1A202C); // High-precision card background
  static const headerBackground = Color(0xFF0D1017); // Sleek deep slate header

  // Typography & Text
  static const textPrimary = Color(0xFFF1F5F9); // Crisp Slate-100 high-contrast text
  static const textSecondary = Color(0xFF94A3B8); // Slate-400 clean technical subtext
  static const border = Color(0xFF2D3748); // Slate hairline precision border

  // High-Visibility Telemetry Indicators (No Blue)
  static const critical = Color(0xFFF87171); // Safety Alert Crimson
  static const warning = Color(0xFFFBBF24); // Telemetry Amber
  static const success = Color(0xFF34D399); // Nominal Telemetry Mint
}

ThemeData buildTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: Color(0xFF064E3B),
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.primaryLight,
    onSecondary: AppColors.onPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.border,
    error: AppColors.critical,
    onError: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.surface,
    cardColor: AppColors.cardBackground,

    // Sleek High-Tech Header
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.headerBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // Precision Flat Cards with 1px Hairline Slate Border
    cardTheme: CardThemeData(
      color: AppColors.cardBackground,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),

    // High-Contrast Cyber Mint Action Buttons
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.2),
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

    // Modern Technical Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainer,
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
      backgroundColor: const Color(0xFF1E2636),
      contentTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}