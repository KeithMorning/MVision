import 'package:flutter/material.dart';

/// Color tokens for MVision.
///
/// Supports light and dark themes.
class AppColors {
  const AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimaryContainer = Color(0xFF1E3A8A);

  // Surface colors
  static const Color surface = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF0F0F0F);
  static const Color surfaceVariant = Color(0xFFF4F4F5);
  static const Color surfaceVariantDark = Color(0xFF1F1F1F);

  // Background colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF000000);

  // Text colors
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFCA8A04);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // AI indicator (subtle, not overwhelming)
  static const Color aiIndicator = Color(0xFF8B5CF6);
  static const Color aiIndicatorDark = Color(0xFFA78BFA);

  // Border colors
  static const Color border = Color(0xFFE4E4E7);
  static const Color borderDark = Color(0xFF27272A);

  // Overlay
  static const Color overlay = Color(0x66000000);
  static const Color overlayDark = Color(0x66FFFFFF);
}

/// Light theme color scheme.
final lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.primaryContainer,
  onPrimaryContainer: AppColors.onPrimaryContainer,
  secondary: AppColors.primary,
  onSecondary: AppColors.onPrimary,
  secondaryContainer: AppColors.primaryContainer,
  onSecondaryContainer: AppColors.onPrimaryContainer,
  tertiary: AppColors.aiIndicator,
  onTertiary: AppColors.onPrimary,
  error: AppColors.error,
  onError: AppColors.onPrimary,
  surface: AppColors.surface,
  onSurface: AppColors.textPrimary,
  surfaceContainerHighest: AppColors.surfaceVariant,
  outline: AppColors.border,
  shadow: AppColors.overlay,
);

/// Dark theme color scheme.
final darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.primaryContainer,
  onPrimaryContainer: AppColors.onPrimaryContainer,
  secondary: AppColors.primary,
  onSecondary: AppColors.onPrimary,
  secondaryContainer: AppColors.primaryContainer,
  onSecondaryContainer: AppColors.onPrimaryContainer,
  tertiary: AppColors.aiIndicatorDark,
  onTertiary: AppColors.textPrimaryDark,
  error: AppColors.error,
  onError: AppColors.onPrimary,
  surface: AppColors.surfaceDark,
  onSurface: AppColors.textPrimaryDark,
  surfaceContainerHighest: AppColors.surfaceVariantDark,
  outline: AppColors.borderDark,
  shadow: AppColors.overlayDark,
);
