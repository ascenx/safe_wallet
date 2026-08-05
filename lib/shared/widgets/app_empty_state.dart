import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

final class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.message,
    this.icon = AppIcons.inbox,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.appColors.textMuted),
            const SizedBox(height: 8),
            Text(message, style: context.appTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
