import 'package:flutter/material.dart';

final class AppColors {
  const AppColors._();

  static const background = Color(0xFFF8FAFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF9FBFF);
  static const border = Color(0xFFD6DEEA);
  static const divider = Color(0xFFE9EDF5);
  static const textPrimary = Color(0xFF080A12);
  static const textSecondary = Color(0xFF68738A);
  static const textMuted = Color(0xFF8A94AA);

  static const darkBackground = Color(0xFF0B0F1A);
  static const darkSurface = Color(0xFF121826);
  static const darkSurfaceSoft = Color(0xFF171F2F);
  static const darkBorder = Color(0xFF293348);
  static const darkDivider = Color(0xFF202A3B);
  static const darkTextPrimary = Color(0xFFF7F9FC);
  static const darkTextSecondary = Color(0xFFAAB4C8);
  static const darkTextMuted = Color(0xFF7F8AA3);

  static const primary = Color(0xFF5265FF);
  static const primaryDark = Color(0xFF384BEE);
  static const primarySoft = Color(0xFFEEF1FF);
  static const purple = Color(0xFF725CFF);
  static const success = Color(0xFF18BFA3);
  static const successSoft = Color(0xFFE8FAF6);
  static const danger = Color(0xFFFF3F62);
  static const dangerSoft = Color(0xFFFFF0F3);
  static const warning = Color(0xFFF6A609);
  static const warningSoft = Color(0xFFFFF7E6);
  static const darkSuccessSoft = Color(0xFF123A35);
  static const darkDangerSoft = Color(0xFF3B1822);
  static const darkWarningSoft = Color(0xFF3B2C12);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF6C7BFF), Color(0xFF4A5CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientEthereum = LinearGradient(
    colors: [Color(0xFF8BA0FF), Color(0xFF384BEE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientSuccess = LinearGradient(
    colors: [Color(0xFF36D6B6), Color(0xFF16B99D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.successSoft,
    required this.dangerSoft,
    required this.warningSoft,
  });

  static const light = AppSemanticColors(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceSoft: AppColors.surfaceSoft,
    border: AppColors.border,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    successSoft: AppColors.successSoft,
    dangerSoft: AppColors.dangerSoft,
    warningSoft: AppColors.warningSoft,
  );

  static const dark = AppSemanticColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceSoft: AppColors.darkSurfaceSoft,
    border: AppColors.darkBorder,
    divider: AppColors.darkDivider,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    textMuted: AppColors.darkTextMuted,
    successSoft: AppColors.darkSuccessSoft,
    dangerSoft: AppColors.darkDangerSoft,
    warningSoft: AppColors.darkWarningSoft,
  );

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color successSoft;
  final Color dangerSoft;
  final Color warningSoft;

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? successSoft,
    Color? dangerSoft,
    Color? warningSoft,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      successSoft: successSoft ?? this.successSoft,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      warningSoft: warningSoft ?? this.warningSoft,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
    );
  }
}

extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
