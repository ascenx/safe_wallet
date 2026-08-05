import 'package:flutter/material.dart';

enum AppThemeColor { indigo, blue, purple, green, orange, rose, navy }

final class AppThemePalette {
  const AppThemePalette({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.gradientColors,
  });

  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final List<Color> gradientColors;
}

extension AppThemeColorPalette on AppThemeColor {
  AppThemePalette get palette => switch (this) {
    AppThemeColor.indigo => const AppThemePalette(
      primary: Color(0xFF5265FF),
      primaryDark: Color(0xFF384BEE),
      primarySoft: Color(0xFFEEF1FF),
      gradientColors: [Color(0xFF6C7BFF), Color(0xFF4A5CFF)],
    ),
    AppThemeColor.blue => const AppThemePalette(
      primary: Color(0xFF1769E0),
      primaryDark: Color(0xFF0F52BA),
      primarySoft: Color(0xFFEAF2FF),
      gradientColors: [Color(0xFF3684F0), Color(0xFF115CCF)],
    ),
    AppThemeColor.purple => const AppThemePalette(
      primary: Color(0xFF6F42E8),
      primaryDark: Color(0xFF5830C8),
      primarySoft: Color(0xFFF2ECFF),
      gradientColors: [Color(0xFF875CF2), Color(0xFF6239D9)],
    ),
    AppThemeColor.green => const AppThemePalette(
      primary: Color(0xFF078260),
      primaryDark: Color(0xFF05694D),
      primarySoft: Color(0xFFE7F7F1),
      gradientColors: [Color(0xFF12A77C), Color(0xFF087258)],
    ),
    AppThemeColor.orange => const AppThemePalette(
      primary: Color(0xFFC96200),
      primaryDark: Color(0xFFA64F00),
      primarySoft: Color(0xFFFFF0E2),
      gradientColors: [Color(0xFFE87C18), Color(0xFFB95600)],
    ),
    AppThemeColor.rose => const AppThemePalette(
      primary: Color(0xFFD63C64),
      primaryDark: Color(0xFFB92C50),
      primarySoft: Color(0xFFFFEAF0),
      gradientColors: [Color(0xFFE85A7E), Color(0xFFC9345B)],
    ),
    AppThemeColor.navy => const AppThemePalette(
      primary: Color(0xFF1A3054),
      primaryDark: Color(0xFF10213C),
      primarySoft: Color(0xFFE9EEF5),
      gradientColors: [Color(0xFF2B4A78), Color(0xFF142A4A)],
    ),
  };
}

final class AppBrandColors extends ThemeExtension<AppBrandColors> {
  const AppBrandColors({
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryGradient,
  });

  final Color primaryDark;
  final Color primarySoft;
  final LinearGradient primaryGradient;

  factory AppBrandColors.fromThemeColor(
    AppThemeColor themeColor, {
    Brightness brightness = Brightness.light,
  }) {
    final palette = themeColor.palette;
    return AppBrandColors(
      primaryDark: palette.primaryDark,
      primarySoft: brightness == Brightness.dark
          ? Color.alphaBlend(
              palette.primary.withValues(alpha: 0.24),
              const Color(0xFF171F2F),
            )
          : palette.primarySoft,
      primaryGradient: LinearGradient(
        colors: palette.gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  @override
  AppBrandColors copyWith({
    Color? primaryDark,
    Color? primarySoft,
    LinearGradient? primaryGradient,
  }) {
    return AppBrandColors(
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  AppBrandColors lerp(AppBrandColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppBrandColors(
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
    );
  }
}

extension AppBrandColorsContext on BuildContext {
  AppBrandColors get brandColors =>
      Theme.of(this).extension<AppBrandColors>() ??
      AppBrandColors.fromThemeColor(AppThemeColor.indigo);
}
