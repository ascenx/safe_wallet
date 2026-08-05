import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../i18n/generated/translations.g.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import 'app_buttons.dart';

enum AppDialogActionVariant { primary, danger, text }

final class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    this.cancelCallback,
    this.confirmCallback,
    this.cancelTitle,
    this.confirmTitle,
    this.cancelKey,
    this.confirmKey,
    this.cancelChild,
    this.confirmChild,
    this.showCancel,
    this.showConfirm,
    this.confirmVariant = AppDialogActionVariant.primary,
    super.key,
  });

  final String title;
  final Widget content;
  final VoidCallback? cancelCallback;
  final VoidCallback? confirmCallback;
  final String? cancelTitle;
  final String? confirmTitle;
  final Key? cancelKey;
  final Key? confirmKey;
  final Widget? cancelChild;
  final Widget? confirmChild;
  final bool? showCancel;
  final bool? showConfirm;
  final AppDialogActionVariant confirmVariant;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    VoidCallback? cancelCallback,
    VoidCallback? confirmCallback,
    String? cancelTitle,
    String? confirmTitle,
    Key? cancelKey,
    Key? confirmKey,
    Widget? cancelChild,
    Widget? confirmChild,
    bool? showCancel,
    bool? showConfirm,
    AppDialogActionVariant confirmVariant = AppDialogActionVariant.primary,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog(
        title: title,
        content: content,
        cancelCallback: cancelCallback,
        confirmCallback: confirmCallback,
        cancelTitle: cancelTitle,
        confirmTitle: confirmTitle,
        cancelKey: cancelKey,
        confirmKey: confirmKey,
        cancelChild: cancelChild,
        confirmChild: confirmChild,
        showCancel: showCancel,
        showConfirm: showConfirm,
        confirmVariant: confirmVariant,
      ),
    );
  }

  static Future<T?> showBuilder<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = math.max(0.0, MediaQuery.sizeOf(context).width - 64);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      constraints: BoxConstraints(minWidth: dialogWidth, maxWidth: dialogWidth),
      title: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(
          color: context.appColors.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      content: content,
      actions: _hasActions
          ? [
              _AppDialogActions(
                cancelCallback: cancelCallback,
                confirmCallback: confirmCallback,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                cancelKey: cancelKey,
                confirmKey: confirmKey,
                cancelChild: cancelChild,
                confirmChild: confirmChild,
                showCancel: _showsCancel,
                showConfirm: _showsConfirm,
                confirmVariant: confirmVariant,
              ),
            ]
          : null,
    );
  }

  bool get _showsCancel => showCancel ?? cancelCallback != null;

  bool get _showsConfirm => showConfirm ?? confirmCallback != null;

  bool get _hasActions => _showsCancel || _showsConfirm;
}

final class _AppDialogActions extends StatelessWidget {
  const _AppDialogActions({
    required this.cancelCallback,
    required this.confirmCallback,
    required this.cancelTitle,
    required this.confirmTitle,
    required this.cancelKey,
    required this.confirmKey,
    required this.cancelChild,
    required this.confirmChild,
    required this.showCancel,
    required this.showConfirm,
    required this.confirmVariant,
  });

  final VoidCallback? cancelCallback;
  final VoidCallback? confirmCallback;
  final String? cancelTitle;
  final String? confirmTitle;
  final Key? cancelKey;
  final Key? confirmKey;
  final Widget? cancelChild;
  final Widget? confirmChild;
  final bool showCancel;
  final bool showConfirm;
  final AppDialogActionVariant confirmVariant;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (showCancel)
        Expanded(
          child: AppButton.text(
            key: cancelKey,
            label: cancelTitle ?? t.actions.cancel,
            height: 40,
            onPressed: cancelCallback,
            child: cancelChild,
          ),
        ),
      if (showCancel && showConfirm) const SizedBox(width: 12),
      if (showConfirm) Expanded(child: _confirmButton()),
    ];

    return SizedBox(height: 40, child: Row(children: buttons));
  }

  Widget _confirmButton() {
    final label = confirmTitle ?? t.actions.confirm;

    return switch (confirmVariant) {
      AppDialogActionVariant.primary => AppButton.primary(
        key: confirmKey,
        label: label,
        height: 40,
        onPressed: confirmCallback,
        child: confirmChild,
      ),
      AppDialogActionVariant.danger => AppButton.danger(
        key: confirmKey,
        label: label,
        height: 40,
        onPressed: confirmCallback,
        child: confirmChild,
      ),
      AppDialogActionVariant.text => AppButton.text(
        key: confirmKey,
        label: label,
        height: 40,
        onPressed: confirmCallback,
        child: confirmChild,
      ),
    };
  }
}
