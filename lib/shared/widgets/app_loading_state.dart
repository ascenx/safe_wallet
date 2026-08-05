import 'package:flutter/material.dart';

import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';

final class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    this.message,
    super.key,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, style: context.appTextStyles.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
