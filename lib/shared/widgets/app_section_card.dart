import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../design/app_spacing.dart';

final class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.borderRadius = AppRadius.mediumBorder,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? colorScheme.outline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
