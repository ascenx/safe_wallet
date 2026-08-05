import 'package:flutter/material.dart';

import '../../i18n/generated/translations.g.dart';
import '../design/app_icons.dart';

final class AppPasswordTextField extends StatefulWidget {
  const AppPasswordTextField({
    required this.controller,
    required this.decoration,
    this.fieldKey,
    this.visibilityButtonKey,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final Key? fieldKey;
  final Key? visibilityButtonKey;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppPasswordTextField> createState() => _AppPasswordTextFieldState();
}

final class _AppPasswordTextFieldState extends State<AppPasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final visibilityLabel = _obscureText
        ? t.actions.showPassword
        : t.actions.hidePassword;

    return TextField(
      key: widget.fieldKey,
      spellCheckConfiguration: SpellCheckConfiguration.disabled(),
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      controller: widget.controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: _obscureText,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          key: widget.visibilityButtonKey,
          tooltip: visibilityLabel,
          onPressed: widget.enabled
              ? () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                }
              : null,
          icon: Icon(
            _obscureText ? AppIcons.visible : AppIcons.hidden,
            size: 20,
          ),
        ),
      ),
      onSubmitted: widget.onSubmitted,
    );
  }
}
