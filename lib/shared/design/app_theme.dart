import 'package:flutter/material.dart';

import 'app_brand_colors.dart';
import 'app_colors.dart';
import 'app_icons.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

ThemeData buildAppTheme([AppThemeColor themeColor = AppThemeColor.indigo]) {
  return _buildAppTheme(themeColor, Brightness.light);
}

ThemeData buildAppDarkTheme([AppThemeColor themeColor = AppThemeColor.indigo]) {
  return _buildAppTheme(themeColor, Brightness.dark);
}

ThemeData _buildAppTheme(AppThemeColor themeColor, Brightness brightness) {
  final palette = themeColor.palette;
  final isDark = brightness == Brightness.dark;
  final background = isDark ? AppColors.darkBackground : AppColors.background;
  final surface = isDark ? AppColors.darkSurface : AppColors.surface;
  final surfaceSoft = isDark
      ? AppColors.darkSurfaceSoft
      : AppColors.surfaceSoft;
  final border = isDark ? AppColors.darkBorder : AppColors.border;
  final divider = isDark ? AppColors.darkDivider : AppColors.divider;
  final textPrimary = isDark
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final textSecondary = isDark
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;
  final brandColors = AppBrandColors.fromThemeColor(
    themeColor,
    brightness: brightness,
  );
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
    primary: palette.primary,
    surface: surface,
    error: AppColors.danger,
  ).copyWith(
    onSurface: textPrimary,
    outline: border,
    outlineVariant: divider,
  );

  final theme = ThemeData(
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    colorScheme: colorScheme,
    extensions: [
      brandColors,
      isDark ? AppSemanticColors.dark : AppSemanticColors.light,
    ],
    scaffoldBackgroundColor: background,
    dividerColor: divider,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: isDark
          ? AppTextStyles.titleMedium.copyWith(color: textPrimary)
          : AppTextStyles.titleMedium,
    ),
    textTheme: TextTheme(
      displayLarge: AppTextStyles.displayAmount.copyWith(color: textPrimary),
      headlineLarge: AppTextStyles.titleLarge.copyWith(color: textPrimary),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: textPrimary),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: textPrimary),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: textPrimary),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: textPrimary),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: textSecondary),
      labelSmall: AppTextStyles.caption.copyWith(color: textMuted),
      labelMedium: AppTextStyles.tabLabel.copyWith(color: textMuted),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xLargeBorder,
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: palette.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorder,
        borderSide: BorderSide(color: AppColors.danger),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: brandColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTextStyles.tabLabel.copyWith(color: palette.primary);
        }
        return AppTextStyles.tabLabel.copyWith(color: textMuted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: palette.primary, size: 28);
        }
        return IconThemeData(color: textMuted, size: 28);
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        textStyle: AppTextStyles.bodyLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
        ),
        textStyle: AppTextStyles.bodyLarge,
      ),
    ),
  );

  return theme.copyWith(
    iconTheme: theme.iconTheme.copyWith(size: AppIconSize.action),
  );
}
