import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_radius.dart';
import 'package:safe_wallet/shared/design/app_spacing.dart';
import 'package:safe_wallet/shared/design/app_text_styles.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  group('App design tokens', () {
    test('match the key color values from DESIGN.md', () {
      expect(AppColors.primary.toARGB32(), 0xFF5265FF);
      expect(AppColors.background.toARGB32(), 0xFFF8FAFF);
      expect(AppColors.surface.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.border.toARGB32(), 0xFFD6DEEA);
      expect(AppColors.success.toARGB32(), 0xFF18BFA3);
      expect(AppColors.danger.toARGB32(), 0xFFFF3F62);
    });

    test('match the key spacing and radius values from DESIGN.md', () {
      expect(AppRadius.small, 8);
      expect(AppRadius.medium, 12);
      expect(AppRadius.large, 18);
      expect(AppRadius.xLarge, 22);
      expect(AppRadius.pill, 999);
      expect(AppSpacing.pageX, 16);
      expect(AppSpacing.sectionY, 12);
      expect(AppSpacing.cardPaddingLarge, 20);
    });

    test('define stable text styles for wallet screens', () {
      expect(AppTextStyles.displayAmount.fontSize, 34);
      expect(AppTextStyles.displayAmount.fontWeight, FontWeight.w700);
      expect(AppTextStyles.titleLarge.fontSize, 22);
      expect(AppTextStyles.bodyMedium.fontSize, 15);
      expect(AppTextStyles.tabLabel.letterSpacing, 0);
    });

    test('builds a light theme from the design tokens', () {
      final theme = buildAppTheme();

      expect(theme.scaffoldBackgroundColor.toARGB32(), 0xFFF8FAFF);
      expect(theme.colorScheme.primary.toARGB32(), 0xFF5265FF);
      expect(theme.cardTheme.color?.toARGB32(), 0xFFFFFFFF);
      expect(theme.useMaterial3, isTrue);
    });

    test('builds a dark theme from dark semantic colors', () {
      final theme = buildAppDarkTheme();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor.toARGB32(), 0xFF0B0F1A);
      expect(theme.cardTheme.color?.toARGB32(), 0xFF121826);
      expect(theme.colorScheme.onSurface.toARGB32(), 0xFFF7F9FC);
      expect(theme.dividerColor.toARGB32(), 0xFF202A3B);
    });

    test('uses the smaller title style for app bar titles', () {
      final theme = buildAppTheme();

      expect(theme.appBarTheme.titleTextStyle, AppTextStyles.titleMedium);
    });

    test('uses 20 as the default icon size', () {
      final theme = buildAppTheme();

      expect(theme.iconTheme.size, 20);
      expect(theme.iconTheme.color, isNotNull);
    });

    test('disables global ink ripple animations', () {
      final theme = buildAppTheme();

      expect(theme.splashFactory, NoSplash.splashFactory);
    });
  });
}
