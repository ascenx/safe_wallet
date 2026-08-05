import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../i18n/application/locale_controller.dart';

final class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t;
    final selectedMode =
        ref.watch(localeControllerProvider).value ?? AppLocaleMode.system;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings.language)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.sectionY,
            AppSpacing.pageX,
            AppSpacing.pageX,
          ),
          children: [
            _LanguageChoice(
              title: strings.settings.languageSystem,
              value: AppLocaleMode.system,
              groupValue: selectedMode,
              onChanged: (mode) => _setMode(ref, mode),
            ),
            _LanguageChoice(
              title: strings.settings.languageZh,
              value: AppLocaleMode.zh,
              groupValue: selectedMode,
              onChanged: (mode) => _setMode(ref, mode),
            ),
            _LanguageChoice(
              title: strings.settings.languageEn,
              value: AppLocaleMode.en,
              groupValue: selectedMode,
              onChanged: (mode) => _setMode(ref, mode),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setMode(WidgetRef ref, AppLocaleMode? mode) async {
    if (mode == null) {
      return;
    }
    await ref.read(localeControllerProvider.notifier).setMode(mode);
  }
}

final class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final AppLocaleMode value;
  final AppLocaleMode groupValue;
  final ValueChanged<AppLocaleMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      leading: Icon(
        selected ? AppIcons.radioSelected : AppIcons.radio,
      ),
      title: Text(title),
      onTap: () => onChanged(value),
    );
  }
}
