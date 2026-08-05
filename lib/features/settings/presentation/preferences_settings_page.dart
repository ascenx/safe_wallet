import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../i18n/application/locale_controller.dart';
import '../application/fiat_currency_setting.dart';
import '../application/theme_color_setting.dart';
import '../application/theme_mode_setting.dart';
import 'theme_color_settings_page.dart';

final class PreferencesSettingsPage extends ConsumerWidget {
  const PreferencesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedThemeColor =
        ref.watch(themeColorSettingProvider).value ?? AppThemeColor.indigo;
    final selectedThemeMode =
        ref.watch(themeModeSettingProvider).value ?? AppThemeMode.light;
    final selectedLocaleMode =
        ref.watch(localeControllerProvider).value ?? AppLocaleMode.system;
    final selectedFiatCurrency =
        ref.watch(fiatCurrencySettingProvider).value ?? AppFiatCurrency.usd;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.settings.preferences)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.sectionY,
            AppSpacing.pageX,
            AppSpacing.pageX,
          ),
          children: [
            _PreferenceRow(
              icon: AppIcons.language,
              label: context.t.settings.language,
              trailing: Text(
                _localeModeLabel(context, selectedLocaleMode),
                style: context.appTextStyles.bodySmall,
              ),
              onTap: () => _selectLanguage(context, ref, selectedLocaleMode),
            ),
            _PreferenceRow(
              icon: AppIcons.appearance,
              label: context.t.settings.themeMode,
              trailing: Text(
                _themeModeLabel(context, selectedThemeMode),
                style: context.appTextStyles.bodySmall,
              ),
              onTap: () => _selectThemeMode(context, ref, selectedThemeMode),
            ),
            _PreferenceRow(
              icon: AppIcons.palette,
              label: context.t.settings.themeColor,
              trailing: _ThemeColorSummary(
                themeColor: selectedThemeColor,
                label: _themeColorLabel(context, selectedThemeColor),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ThemeColorSettingsPage(),
                ),
              ),
            ),
            _PreferenceRow(
              icon: AppIcons.bank,
              label: context.t.settings.fiatCurrency,
              trailing: Text(
                selectedFiatCurrency.code,
                style: context.appTextStyles.bodySmall,
              ),
              onTap: () =>
                  _selectFiatCurrency(context, ref, selectedFiatCurrency),
            ),
          ],
        ),
      ),
    );
  }

  String _themeColorLabel(BuildContext context, AppThemeColor themeColor) {
    final strings = context.t.settings;
    return switch (themeColor) {
      AppThemeColor.indigo => strings.themeColorIndigo,
      AppThemeColor.blue => strings.themeColorBlue,
      AppThemeColor.purple => strings.themeColorPurple,
      AppThemeColor.green => strings.themeColorGreen,
      AppThemeColor.orange => strings.themeColorOrange,
      AppThemeColor.rose => strings.themeColorRose,
      AppThemeColor.navy => strings.themeColorNavy,
    };
  }

  Future<void> _selectThemeMode(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode selectedMode,
  ) async {
    final strings = context.t.settings;
    final mode = await showAppActionSheet<AppThemeMode>(
      context,
      title: strings.themeMode,
      actions: [
        AppActionSheetAction(
          value: AppThemeMode.system,
          icon: AppIcons.appearance,
          title: strings.themeModeSystem,
          isSelected: selectedMode == AppThemeMode.system,
        ),
        AppActionSheetAction(
          value: AppThemeMode.light,
          icon: AppIcons.lightMode,
          title: strings.themeModeLight,
          isSelected: selectedMode == AppThemeMode.light,
        ),
        AppActionSheetAction(
          value: AppThemeMode.dark,
          icon: AppIcons.darkMode,
          title: strings.themeModeDark,
          isSelected: selectedMode == AppThemeMode.dark,
        ),
      ],
    );
    if (mode == null) {
      return;
    }
    await ref.read(themeModeSettingProvider.notifier).setThemeMode(mode);
  }

  String _themeModeLabel(BuildContext context, AppThemeMode mode) {
    final strings = context.t.settings;
    return switch (mode) {
      AppThemeMode.system => strings.themeModeSystem,
      AppThemeMode.light => strings.themeModeLight,
      AppThemeMode.dark => strings.themeModeDark,
    };
  }

  String _localeModeLabel(BuildContext context, AppLocaleMode mode) {
    final strings = context.t.settings;
    return switch (mode) {
      AppLocaleMode.system => strings.languageSystem,
      AppLocaleMode.zh => strings.languageZh,
      AppLocaleMode.en => strings.languageEn,
    };
  }

  Future<void> _selectLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLocaleMode selectedMode,
  ) async {
    final strings = context.t.settings;
    final mode = await showAppActionSheet<AppLocaleMode>(
      context,
      title: strings.language,
      actions: [
        AppActionSheetAction(
          value: AppLocaleMode.system,
          icon: AppIcons.language,
          title: strings.languageSystem,
          isSelected: selectedMode == AppLocaleMode.system,
        ),
        AppActionSheetAction(
          value: AppLocaleMode.zh,
          icon: AppIcons.language,
          title: strings.languageZh,
          isSelected: selectedMode == AppLocaleMode.zh,
        ),
        AppActionSheetAction(
          value: AppLocaleMode.en,
          icon: AppIcons.language,
          title: strings.languageEn,
          isSelected: selectedMode == AppLocaleMode.en,
        ),
      ],
    );
    if (mode == null) {
      return;
    }
    await ref.read(localeControllerProvider.notifier).setMode(mode);
  }

  Future<void> _selectFiatCurrency(
    BuildContext context,
    WidgetRef ref,
    AppFiatCurrency selectedCurrency,
  ) async {
    final strings = context.t.settings;
    final currency = await showAppActionSheet<AppFiatCurrency>(
      context,
      title: strings.fiatCurrency,
      actions: [
        for (final currency in AppFiatCurrency.values)
          AppActionSheetAction(
            value: currency,
            icon: AppIcons.bank,
            title: _fiatCurrencyLabel(context, currency),
            isSelected: selectedCurrency == currency,
          ),
      ],
    );
    if (currency == null) {
      return;
    }
    await ref.read(fiatCurrencySettingProvider.notifier).setCurrency(currency);
  }

  String _fiatCurrencyLabel(BuildContext context, AppFiatCurrency currency) {
    final strings = context.t.settings;
    return switch (currency) {
      AppFiatCurrency.usd => strings.fiatCurrencyUsd,
      AppFiatCurrency.cny => strings.fiatCurrencyCny,
      AppFiatCurrency.eur => strings.fiatCurrencyEur,
      AppFiatCurrency.jpy => strings.fiatCurrencyJpy,
    };
  }
}

final class _ThemeColorSummary extends StatelessWidget {
  const _ThemeColorSummary({required this.themeColor, required this.label});

  final AppThemeColor themeColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: themeColor.palette.primary,
            shape: BoxShape.circle,
          ),
          child: const SizedBox.square(dimension: 12),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.appTextStyles.bodySmall),
      ],
    );
  }
}

final class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: InkWell(
        borderRadius: AppRadius.xLargeBorder,
        onTap: onTap,
        child: AppSectionCard(
          padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
          borderRadius: AppRadius.xLargeBorder,
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: context.appTextStyles.bodyLarge)),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              Icon(
                AppIcons.chevronRight,
                color: context.appColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
