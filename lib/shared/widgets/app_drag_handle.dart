import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../design/app_spacing.dart';

final class AppDragHandle extends StatelessWidget {
  const AppDragHandle({
    this.paddingKey = const Key('appDragHandle'),
    super.key,
  });

  final Key paddingKey;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        key: paddingKey,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sectionY),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius: AppRadius.pillBorder,
          ),
          child: const SizedBox(width: 36, height: 4),
        ),
      ),
    );
  }
}
