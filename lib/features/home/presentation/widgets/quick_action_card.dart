import 'package:flutter/material.dart';

import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_text_styles.dart';

final class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppRadius.largeBorder,
            border: Border.all(color: colorScheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 34),
                const SizedBox(height: 10),
                Text(label, style: context.appTextStyles.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
