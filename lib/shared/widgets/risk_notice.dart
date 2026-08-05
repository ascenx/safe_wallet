import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../design/app_colors.dart';
import '../design/app_brand_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

enum RiskLevel {
  info,
  warning,
  danger,
}

final class RiskNotice extends StatelessWidget {
  const RiskNotice({
    required this.level,
    required this.message,
    super.key,
  });

  final RiskLevel level;
  final String message;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _backgroundColor(context);
    final iconColor = _iconColor(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: iconColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: context.appTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }

  Color _backgroundColor(BuildContext context) {
    return switch (level) {
      RiskLevel.info => context.brandColors.primarySoft,
      RiskLevel.warning => context.appColors.warningSoft,
      RiskLevel.danger => context.appColors.dangerSoft,
    };
  }

  Color _iconColor(BuildContext context) {
    return switch (level) {
      RiskLevel.info => Theme.of(context).colorScheme.primary,
      RiskLevel.warning => AppColors.warning,
      RiskLevel.danger => AppColors.danger,
    };
  }

  IconData get _icon {
    return switch (level) {
      RiskLevel.info => AppIcons.info,
      RiskLevel.warning => AppIcons.warning,
      RiskLevel.danger => AppIcons.danger,
    };
  }
}
