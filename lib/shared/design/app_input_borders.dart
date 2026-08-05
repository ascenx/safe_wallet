import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

final class AppInputBorders {
  const AppInputBorders._();

  static OutlineInputBorder pill(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: AppRadius.pillBorder,
      borderSide: BorderSide(color: context.appColors.border),
    );
  }

  static OutlineInputBorder pillFocused(BuildContext context) {
    return OutlineInputBorder(
      borderRadius: AppRadius.pillBorder,
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
    );
  }

  static const pillError = OutlineInputBorder(
    borderRadius: AppRadius.pillBorder,
    borderSide: BorderSide(color: AppColors.danger),
  );
}
