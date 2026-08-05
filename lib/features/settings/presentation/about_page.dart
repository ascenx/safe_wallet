import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/network/external_url_launcher.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_drag_handle.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../application/app_update_checker.dart';
import '../application/app_version_provider.dart';

final class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version =
        ref.watch(appVersionProvider).value ?? fallbackAppVersionInfo;
    final updateState = ref.watch(appUpdateCheckControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.about.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.sectionY,
            AppSpacing.pageX,
            AppSpacing.pageX,
          ),
          children: [
            _AppInfoCard(version: version),
            const SizedBox(height: AppSpacing.sectionY),
            _AboutSection(
              title: t.about.versionAndUpdates,
              children: [
                _AboutRow(
                  key: const Key('checkForUpdatesRow'),
                  icon: AppIcons.update,
                  title: updateState.isLoading
                      ? t.about.checkingUpdate
                      : t.about.checkUpdate,
                  onTap: updateState.isLoading
                      ? null
                      : () => _checkForUpdates(context, ref),
                ),
                _AboutRow(
                  icon: AppIcons.notes,
                  title: t.about.releaseNotes,
                  onTap: () => _openExternal(
                    context,
                    ref,
                    safeWalletReleasesUrl,
                  ),
                ),
                _AboutRow(
                  icon: AppIcons.code,
                  title: t.about.github,
                  onTap: () => _openExternal(
                    context,
                    ref,
                    safeWalletGitHubUrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AboutSection(
              title: t.about.transparencyAndSecurity,
              children: [
                _AboutRow(
                  icon: AppIcons.policy,
                  title: t.about.dataAndNetwork,
                  onTap: () => _pushDocument(
                    context,
                    title: t.about.dataAndNetwork,
                    sections: [
                      (t.about.dataLocalTitle, t.about.dataLocalBody),
                      (t.about.backendTitle, t.about.backendBody),
                      (t.about.servicesTitle, t.about.servicesBody),
                      (t.about.analyticsTitle, t.about.analyticsBody),
                    ],
                  ),
                ),
                _AboutRow(
                  icon: AppIcons.article,
                  title: t.about.openSourceLicenses,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: t.app.name,
                    applicationVersion: version.version,
                    applicationIcon: const _AppLogo(size: 48),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AboutSection(
              title: t.about.helpAndLegal,
              children: [
                _AboutRow(
                  icon: AppIcons.bug,
                  title: t.about.feedback,
                  onTap: () => _openExternal(
                    context,
                    ref,
                    safeWalletFeedbackUrl,
                  ),
                ),
                _AboutRow(
                  icon: AppIcons.privacy,
                  title: t.about.privacyPolicy,
                  onTap: () => _pushDocument(
                    context,
                    title: t.about.privacyPolicy,
                    sections: [
                      (t.about.dataLocalTitle, t.about.privacyLocalBody),
                      (t.about.servicesTitle, t.about.privacyNetworkBody),
                      (t.about.analyticsTitle, t.about.privacyNoAnalyticsBody),
                      (t.about.backendTitle, t.about.privacyThirdPartyBody),
                      (t.about.privacyPolicy, t.about.privacyChangeBody),
                    ],
                  ),
                ),
                _AboutRow(
                  icon: AppIcons.legal,
                  title: t.about.termsOfUse,
                  onTap: () => _pushDocument(
                    context,
                    title: t.about.termsOfUse,
                    sections: [
                      (t.about.tagline, t.about.termsSelfCustodyBody),
                      (t.about.termsOfUse, t.about.termsTransactionBody),
                      (t.about.servicesTitle, t.about.termsRiskBody),
                      (t.about.backendTitle, t.about.termsThirdPartyBody),
                      (t.about.termsOfUse, t.about.termsWarrantyBody),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    try {
      final result =
          await ref.read(appUpdateCheckControllerProvider.notifier).check();
      if (!context.mounted) {
        return;
      }
      await _showUpdateResult(context, ref, result);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.about.checkUpdateFailed)),
      );
    }
  }

  Future<void> _showUpdateResult(
    BuildContext context,
    WidgetRef ref,
    AppUpdateCheckResult result,
  ) {
    final release = result.latestRelease;
    final title = release == null
        ? t.about.noReleaseTitle
        : result.updateAvailable
            ? t.about.updateAvailableTitle(version: release.version)
            : t.about.latestVersionTitle;
    final body = release == null
        ? t.about.noReleaseBody
        : result.updateAvailable
            ? release.notes.trim().isEmpty
                ? t.about.releaseNotesEmpty
                : release.notes.trim()
            : t.about.latestVersionBody;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xLarge),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              0,
              AppSpacing.pageX,
              AppSpacing.pageX,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppDragHandle(),
                Text(title, style: context.appTextStyles.titleLarge),
                const SizedBox(height: 8),
                Text(
                  t.about.currentVersion(
                    version: result.currentVersion.version,
                  ),
                  style: context.appTextStyles.bodySmall,
                ),
                if (release?.publishedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t.about.publishedAt(
                      date: _dateLabel(release!.publishedAt!),
                    ),
                    style: context.appTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.sectionY),
                Text(body, style: context.appTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.sectionY),
                if (result.updateAvailable && release != null)
                  AppButton.primary(
                    label: t.about.goToUpdate,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openExternal(context, ref, release.url);
                    },
                  )
                else
                  AppButton.secondary(
                    label: t.about.close,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final opened =
        await ref.read(externalUrlLauncherProvider).openExternal(url);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.about.openLinkFailed)),
      );
    }
  }

  void _pushDocument(
    BuildContext context, {
    required String title,
    required List<(String, String)> sections,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AboutDocumentPage(
          title: title,
          sections: sections,
        ),
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

final class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({required this.version});

  final AppVersionInfo version;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        children: [
          const _AppLogo(
            size: 72,
            imageKey: Key('aboutAppLogo'),
          ),
          const SizedBox(height: 12),
          Text(t.app.name, style: context.appTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(t.about.tagline, style: context.appTextStyles.bodySmall),
          const SizedBox(height: 8),
          Text(
            t.about.version(
              version: version.version,
              buildNumber: version.buildNumber,
            ),
            style: context.appTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size, this.imageKey});

  final double size;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SvgPicture.asset(
        'assets/common/logo.svg',
        key: imageKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

final class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.appTextStyles.titleMedium),
        const SizedBox(height: 8),
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          children[index],
        ],
      ],
    );
  }
}

final class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.mediumBorder,
      onTap: onTap,
      child: AppSectionCard(
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: context.appTextStyles.bodyLarge)),
            Icon(AppIcons.chevronRight, color: context.appColors.textMuted),
          ],
        ),
      ),
    );
  }
}

final class _AboutDocumentPage extends StatelessWidget {
  const _AboutDocumentPage({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          itemCount: sections.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppSpacing.sectionY),
          itemBuilder: (context, index) {
            final section = sections[index];
            return AppSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.$1, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(section.$2, style: context.appTextStyles.bodyMedium),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
