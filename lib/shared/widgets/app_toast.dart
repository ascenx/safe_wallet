import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../design/app_colors.dart';
import '../design/app_brand_colors.dart';
import '../design/app_radius.dart';
import '../design/app_text_styles.dart';

enum AppToastVariant { success, error, info }

final class AppToast {
  const AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    AppToastVariant variant = AppToastVariant.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _removeCurrent();
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final top = MediaQuery.paddingOf(overlayContext).top + 16;
        return Positioned(
          top: top,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: _AppToastBody(message: message, variant: variant),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _removeCurrent);
  }

  static void _removeCurrent() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

final class _AppToastBody extends StatelessWidget {
  const _AppToastBody({
    required this.message,
    required this.variant,
  });

  final String message;
  final AppToastVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);

    return Material(
      color: Colors.transparent,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: AppRadius.mediumBorder,
            border: Border.all(color: colors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(colors.icon, size: 18, color: colors.foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: context.appTextStyles.bodySmall.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _AppToastColors _colors(BuildContext context) {
    return switch (variant) {
      AppToastVariant.success => _AppToastColors(
          background: context.appColors.successSoft,
          border: AppColors.success,
          foreground: AppColors.success,
          icon: AppIcons.checkCircle,
        ),
      AppToastVariant.error => _AppToastColors(
          background: context.appColors.dangerSoft,
          border: AppColors.danger,
          foreground: AppColors.danger,
          icon: AppIcons.error,
        ),
      AppToastVariant.info => _AppToastColors(
          background: context.brandColors.primarySoft,
          border: Theme.of(context).colorScheme.primary,
          foreground: Theme.of(context).colorScheme.primary,
          icon: AppIcons.info,
        ),
    };
  }
}

final class _AppToastColors {
  const _AppToastColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
