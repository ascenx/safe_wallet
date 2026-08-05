import 'package:flutter/material.dart';

import '../design/app_radius.dart';
import '../design/app_text_styles.dart';

enum _AppButtonVariant { primary, secondary, danger, text }

final class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.height = 52,
    this.padding,
    super.key,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.height = 52,
    this.padding,
    super.key,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.height = 52,
    this.padding,
    super.key,
  }) : _variant = _AppButtonVariant.danger;

  const AppButton.text({
    required this.label,
    required this.onPressed,
    this.child,
    this.icon,
    this.height = 52,
    this.padding,
    super.key,
  }) : _variant = _AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? icon;
  final double height;
  final EdgeInsetsGeometry? padding;
  final _AppButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    return SizedBox(
      height: height,
      child: switch (_variant) {
        _AppButtonVariant.primary => _filledButton(
          style: _filledStyle(primary, Colors.white),
        ),
        _AppButtonVariant.secondary => _outlinedButton(
          style: _outlinedStyle(foregroundColor: null, borderColor: primary),
        ),
        _AppButtonVariant.danger => _filledButton(
          style: _filledStyle(colorScheme.error, colorScheme.onError),
        ),
        _AppButtonVariant.text => _outlinedButton(
          style: _outlinedStyle(
            foregroundColor: colorScheme.onSurface,
            borderColor: colorScheme.outline,
          ),
        ),
      },
    );
  }

  Widget _filledButton({required ButtonStyle style}) {
    if (icon != null) {
      return FilledButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon!,
        label: _content(),
      );
    }
    return FilledButton(style: style, onPressed: onPressed, child: _content());
  }

  Widget _outlinedButton({required ButtonStyle style}) {
    if (icon != null) {
      return OutlinedButton.icon(
        style: style,
        onPressed: onPressed,
        icon: icon!,
        label: _content(),
      );
    }
    return OutlinedButton(
      style: style,
      onPressed: onPressed,
      child: _content(),
    );
  }

  Widget _content() => child ?? Text(label, maxLines: 1);

  ButtonStyle _filledStyle(Color backgroundColor, Color foregroundColor) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
      textStyle: AppTextStyles.bodyLarge,
      padding: padding,
    );
  }

  ButtonStyle _outlinedStyle({
    required Color? foregroundColor,
    required Color borderColor,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
      side: BorderSide(width: 1, color: borderColor),
      textStyle: AppTextStyles.bodyLarge,
      padding: padding,
    );
  }
}
