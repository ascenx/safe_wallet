import 'package:flutter/material.dart';

import '../../i18n/generated/translations.g.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import 'app_buttons.dart';
import 'app_drag_handle.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required Widget body,
  String? title,
  String? subtitle,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  String? confirmTitle,
  String? cancelTitle,
  bool dismissOnTapOutside = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissOnTapOutside,
    showDragHandle: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xLarge),
      ),
    ),
    builder: (_) => AppBottomSheet(
      title: title,
      subtitle: subtitle,
      onConfirm: onConfirm,
      onCancel: onCancel,
      confirmTitle: confirmTitle,
      cancelTitle: cancelTitle,
      body: body,
    ),
  );
}

final class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.body,
    this.title,
    this.subtitle,
    this.onConfirm,
    this.onCancel,
    this.confirmTitle,
    this.cancelTitle,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String? confirmTitle;
  final String? cancelTitle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasHeader = title != null || subtitle != null;
    final hasActions = onCancel != null || onConfirm != null;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                0,
                AppSpacing.pageX,
                AppSpacing.pageX,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDragHandle(
                    paddingKey: Key('appBottomSheetDragHandle'),
                  ),
                  if (title != null)
                    Text(title!, style: context.appTextStyles.titleLarge),
                  if (title != null && subtitle != null)
                    const SizedBox(height: 8),
                  if (subtitle != null)
                    Text(subtitle!, style: context.appTextStyles.bodySmall),
                  if (hasHeader) const SizedBox(height: AppSpacing.sectionY),
                  body,
                  if (hasActions) ...[
                    const SizedBox(height: AppSpacing.sectionY),
                    _BottomSheetActions(
                      onConfirm: onConfirm,
                      onCancel: onCancel,
                      confirmTitle: confirmTitle,
                      cancelTitle: cancelTitle,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _BottomSheetActions extends StatelessWidget {
  const _BottomSheetActions({
    required this.onConfirm,
    required this.onCancel,
    required this.confirmTitle,
    required this.cancelTitle,
  });

  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String? confirmTitle;
  final String? cancelTitle;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (onCancel != null)
        Expanded(
          child: AppButton.secondary(
            label: cancelTitle ?? t.actions.cancel,
            onPressed: onCancel,
          ),
        ),
      if (onCancel != null && onConfirm != null) const SizedBox(width: 12),
      if (onConfirm != null)
        Expanded(
          child: AppButton.primary(
            label: confirmTitle ?? t.actions.confirm,
            onPressed: onConfirm,
          ),
        ),
    ];

    return Row(children: buttons);
  }
}
