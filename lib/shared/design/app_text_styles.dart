import 'package:flutter/material.dart';

import 'app_colors.dart';

final class AppTextStyles {
  const AppTextStyles._();

  static const displayAmount = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 42 / 34,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 30 / 22,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 26 / 18,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  static const tabLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );
}

final class AppResolvedTextStyles {
  const AppResolvedTextStyles(this._theme);

  final TextTheme _theme;

  TextStyle get displayAmount => _theme.displayLarge!;
  TextStyle get titleLarge => _theme.headlineLarge!;
  TextStyle get titleMedium => _theme.titleMedium!;
  TextStyle get titleSmall => _theme.titleSmall!;
  TextStyle get bodyLarge => _theme.bodyLarge!;
  TextStyle get bodyMedium => _theme.bodyMedium!;
  TextStyle get bodySmall => _theme.bodySmall!;
  TextStyle get caption => _theme.labelSmall!;
  TextStyle get tabLabel => _theme.labelMedium!;
}

extension AppTextStylesContext on BuildContext {
  AppResolvedTextStyles get appTextStyles =>
      AppResolvedTextStyles(Theme.of(this).textTheme);
}
