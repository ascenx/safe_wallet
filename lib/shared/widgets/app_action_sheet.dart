import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../design/app_brand_colors.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';
import '../design/app_text_styles.dart';
import 'app_drag_handle.dart';

enum AppActionSheetActionVariant { normal, danger }

final class AppActionSheetAction<T> {
  const AppActionSheetAction({
    required this.value,
    required this.title,
    this.icon,
    this.subtitle,
    this.variant = AppActionSheetActionVariant.normal,
    this.isSelected = false,
  });

  final T value;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final AppActionSheetActionVariant variant;
  final bool isSelected;
}

Future<T?> showAppActionSheet<T>(
  BuildContext context, {
  required List<AppActionSheetAction<T>> actions,
  String? title,
  String? subtitle,
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
    builder: (_) =>
        AppActionSheet<T>(title: title, subtitle: subtitle, actions: actions),
  );
}

final class AppActionSheet<T> extends StatelessWidget {
  const AppActionSheet({
    required this.actions,
    this.title,
    this.subtitle,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final List<AppActionSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasHeader = title != null || subtitle != null;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
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
                  paddingKey: Key('appActionSheetDragHandle'),
                ),
                if (title != null)
                  Text(title!, style: context.appTextStyles.titleLarge),
                if (title != null && subtitle != null)
                  const SizedBox(height: 8),
                if (subtitle != null)
                  Text(subtitle!, style: context.appTextStyles.bodySmall),
                if (hasHeader) const SizedBox(height: AppSpacing.sectionY),
                Flexible(
                  child: ListView.separated(
                    key: const Key('appActionSheetActionList'),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: actions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) =>
                        _ActionSheetTile<T>(action: actions[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ActionSheetTile<T> extends StatelessWidget {
  const _ActionSheetTile({required this.action});

  final AppActionSheetAction<T> action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brandColors = context.brandColors;
    final isDanger = action.variant == AppActionSheetActionVariant.danger;
    final foregroundColor = isDanger
        ? colorScheme.error
        : colorScheme.onSurface;
    final iconColor = isDanger ? colorScheme.error : colorScheme.primary;
    final iconBackground = isDanger
        ? colorScheme.errorContainer
        : brandColors.primarySoft;

    return Semantics(
      button: true,
      selected: action.isSelected,
      child: Material(
        color: action.isSelected
            ? brandColors.primarySoft
            : colorScheme.surface,
        borderRadius: AppRadius.mediumBorder,
        child: InkWell(
          borderRadius: AppRadius.mediumBorder,
          onTap: () => Navigator.of(context).pop(action.value),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: action.isSelected
                    ? colorScheme.primary
                    : colorScheme.outline,
              ),
              borderRadius: AppRadius.mediumBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  if (action.icon != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: AppRadius.smallBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(action.icon, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          style: context.appTextStyles.bodyLarge.copyWith(
                            color: foregroundColor,
                          ),
                        ),
                        if (action.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            action.subtitle!,
                            style: context.appTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    AppIcons.chevronRight,
                    color: context.appColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
