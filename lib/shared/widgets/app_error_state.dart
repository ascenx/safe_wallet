import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../../i18n/generated/translations.g.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import '../errors/app_error.dart';
import '../errors/error_localizer.dart';

final class AppErrorState extends StatelessWidget {
  const AppErrorState({
    this.error,
    this.message,
    this.localizer = const ErrorLocalizer(),
    super.key,
  }) : assert(error != null || message != null);

  final AppError? error;
  final String? message;
  final ErrorLocalizer localizer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(_message, style: context.appTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }

  String get _message {
    final explicitMessage = message;
    if (explicitMessage != null) {
      return explicitMessage;
    }
    return localizer.messageFor(error!, t);
  }
}
