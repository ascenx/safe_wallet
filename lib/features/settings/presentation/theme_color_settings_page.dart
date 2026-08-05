import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../application/theme_color_setting.dart';

final class ThemeColorSettingsPage extends ConsumerWidget {
  const ThemeColorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedThemeColor =
        ref.watch(themeColorSettingProvider).value ?? AppThemeColor.indigo;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.settings.themeColor)),
      body: GridView.count(
        padding: const EdgeInsets.all(AppSpacing.pageX),
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sectionY,
        crossAxisSpacing: AppSpacing.sectionY,
        childAspectRatio: 1.45,
        children: [
          for (final themeColor in AppThemeColor.values)
            _ThemeColorTile(
              themeColor: themeColor,
              label: _labelFor(context, themeColor),
              selected: themeColor == selectedThemeColor,
              onTap: () => ref
                  .read(themeColorSettingProvider.notifier)
                  .setThemeColor(themeColor),
            ),
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, AppThemeColor themeColor) {
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
}

final class _ThemeColorTile extends StatelessWidget {
  const _ThemeColorTile({
    required this.themeColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeColor themeColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = themeColor.palette;
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: AppRadius.xLargeBorder,
      onTap: onTap,
      child: AppSectionCard(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        borderRadius: AppRadius.xLargeBorder,
        borderColor: selected ? primary : Theme.of(context).dividerColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
              ),
              child: selected
                  ? const Icon(AppIcons.checkCircle, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 10),
            Text(label, style: context.appTextStyles.bodyLarge),
          ],
        ),
      ),
    );
  }
}
