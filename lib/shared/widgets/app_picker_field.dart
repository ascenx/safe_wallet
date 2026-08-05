import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../design/app_radius.dart';
import '../design/app_text_styles.dart';

final class AppPickerField extends StatelessWidget {
  const AppPickerField({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mediumBorder,
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              enabled: onTap != null,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: context.appTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.chevronDown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
