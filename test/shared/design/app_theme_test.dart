import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/design/app_brand_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  test('buildAppTheme exposes the selected semantic brand colors', () {
    final theme = buildAppTheme(AppThemeColor.green);
    final brandColors = theme.extension<AppBrandColors>()!;

    expect(theme.colorScheme.primary, AppThemeColor.green.palette.primary);
    expect(brandColors.primaryDark, AppThemeColor.green.palette.primaryDark);
    expect(brandColors.primarySoft, AppThemeColor.green.palette.primarySoft);
    expect(
      brandColors.primaryGradient.colors,
      AppThemeColor.green.palette.gradientColors,
    );
    expect(
      theme.inputDecorationTheme.focusedBorder?.borderSide.color,
      AppThemeColor.green.palette.primary,
    );
  });

  test('theme presets include the requested deep blue color', () {
    expect(
      AppThemeColor.values.map((color) => color.palette.primary.toARGB32()),
      contains(0xFF1A3054),
    );
  });

  test('app code consumes semantic theme colors instead of fixed primary', () {
    final fixedPrimaryUsage = RegExp(
      r'AppColors\.(primary|primaryDark|primarySoft|gradientPrimary)',
    );
    final violations = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('app_colors.dart'))
        .where((file) => fixedPrimaryUsage.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList(growable: false);

    expect(violations, isEmpty);
  });
}
