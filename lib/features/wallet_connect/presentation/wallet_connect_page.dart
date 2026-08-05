import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/security/inactive_privacy_shield_suppression.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../application/wallet_connect_controller.dart';
import '../application/wallet_connect_project_id_setting.dart';
import '../domain/wallet_connect_models.dart';
import 'wallet_connect_peer_avatar.dart';
import 'wallet_connect_scan_page.dart';

final class WalletConnectPage extends ConsumerStatefulWidget {
  const WalletConnectPage({super.key});

  @override
  ConsumerState<WalletConnectPage> createState() => _WalletConnectPageState();
}

final class _WalletConnectPageState extends ConsumerState<WalletConnectPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(walletConnectControllerProvider.notifier).initialize(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletConnectControllerProvider);
    final projectIdSetting = ref.watch(walletConnectProjectIdSettingProvider);
    final canConnect = state.status == WalletConnectStatus.ready;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.advanced.walletConnect)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(walletConnectControllerProvider.notifier).refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pageX),
            children: [
              _ProjectIdCard(
                setting: projectIdSetting,
                onSet: _setProjectId,
                onDelete: projectIdSetting.customProjectId == null
                    ? null
                    : _deleteProjectId,
              ),
              const SizedBox(height: AppSpacing.sectionY),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      key: const Key('walletConnectScan'),
                      label: context.t.advanced.walletConnectScan,
                      icon: const Icon(AppIcons.qrCode),
                      onPressed: canConnect ? _scan : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      key: const Key('walletConnectPaste'),
                      label: context.t.advanced.walletConnectPaste,
                      icon: const Icon(AppIcons.paste),
                      onPressed: canConnect ? _paste : null,
                    ),
                  ),
                ],
              ),
              if (state.status == WalletConnectStatus.initializing ||
                  state.status == WalletConnectStatus.uninitialized) ...[
                const SizedBox(height: AppSpacing.sectionY),
                const Center(child: CircularProgressIndicator()),
              ],
              if (state.status == WalletConnectStatus.missingConfiguration &&
                  projectIdSetting.source ==
                      WalletConnectProjectIdSource.missing)
                _StatusCard(
                  message: context.t.advanced.walletConnectMissingConfig,
                ),
              if (state.status == WalletConnectStatus.failure)
                _StatusCard(
                  message: context.t.advanced.walletConnectInitializeFailed,
                ),
              const SizedBox(height: AppSpacing.sectionY),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t.advanced.walletConnectActiveSessions,
                      style: context.appTextStyles.titleMedium,
                    ),
                  ),
                  if (state.sessions.isNotEmpty)
                    TextButton(
                      key: const Key('walletConnectDisconnectAll'),
                      onPressed: _disconnectAll,
                      child: Text(
                        context.t.advanced.walletConnectDisconnectAll,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.sessions.isEmpty)
                AppSectionCard(
                  padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
                  child: Text(
                    context.t.advanced.walletConnectNoSessions,
                    style: context.appTextStyles.bodySmall,
                  ),
                )
              else
                for (final session in state.sessions) ...[
                  _SessionCard(
                    session: session,
                    onDisconnect: () => _disconnect(session),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final uri = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const WalletConnectScanPage()),
    );
    if (uri != null && mounted) {
      await _pair(uri);
    }
  }

  Future<void> _paste() async {
    final clipboard = await ref
        .read(inactivePrivacyShieldSuppressionProvider)
        .whileInactiveShieldSuppressed(
          () => Clipboard.getData(Clipboard.kTextPlain),
        );
    if (!mounted) {
      return;
    }
    final controller = TextEditingController(text: clipboard?.text ?? '');
    final uri = await AppDialog.show<String>(
      context: context,
      title: context.t.advanced.walletConnectPaste,
      content: TextField(
        key: const Key('walletConnectUriInput'),
        controller: controller,
        autocorrect: false,
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: context.t.advanced.walletConnectUriHint,
        ),
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmCallback: () => Navigator.of(context).pop(controller.text),
      confirmTitle: context.t.advanced.walletConnectConnect,
    );
    controller.dispose();
    if (uri != null && mounted) {
      await _pair(uri);
    }
  }

  Future<void> _pair(String uri) async {
    final result =
        await ref.read(walletConnectControllerProvider.notifier).pair(uri);
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      WalletConnectPairResult.accepted =>
        context.t.advanced.walletConnectPairStarted,
      WalletConnectPairResult.invalidUri =>
        context.t.advanced.walletConnectInvalidUri,
      WalletConnectPairResult.duplicate =>
        context.t.advanced.walletConnectDuplicateUri,
      WalletConnectPairResult.unavailable ||
      WalletConnectPairResult.failure =>
        context.t.advanced.walletConnectPairFailed,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setProjectId() async {
    final setting = ref.read(walletConnectProjectIdSettingProvider);
    final projectId = await AppDialog.showBuilder<String>(
      context: context,
      builder: (_) => _ProjectIdInputDialog(
        initialValue: setting.customProjectId ?? '',
      ),
    );
    if (projectId == null || !mounted) {
      return;
    }
    if (!isValidReownProjectId(projectId)) {
      _showMessage(context.t.advanced.walletConnectProjectIdInvalid);
      return;
    }
    if (!await _disconnectSessionsForProjectIdChange()) {
      return;
    }
    final saved = await ref
        .read(walletConnectProjectIdSettingProvider.notifier)
        .setCustomProjectId(projectId);
    if (!saved || !mounted) {
      if (mounted) {
        _showMessage(context.t.advanced.walletConnectProjectIdInvalid);
      }
      return;
    }
    final applied =
        await ref.read(walletConnectControllerProvider.notifier).reconfigure();
    if (mounted) {
      _showMessage(
        applied
            ? context.t.advanced.walletConnectProjectIdSaved
            : context.t.advanced.walletConnectProjectIdApplyFailed,
      );
    }
  }

  Future<void> _deleteProjectId() async {
    final setting = ref.read(walletConnectProjectIdSettingProvider);
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.walletConnectProjectIdDeleteTitle,
      content: Text(
        setting.buildProjectId.isEmpty
            ? context.t.advanced.walletConnectProjectIdDeleteWithoutBuild
            : context.t.advanced.walletConnectProjectIdDeleteWithBuild,
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmCallback: () => Navigator.of(context).pop(true),
      confirmTitle: context.t.advanced.walletConnectProjectIdDelete,
      confirmKey: const Key('walletConnectProjectIdDeleteConfirm'),
      confirmVariant: AppDialogActionVariant.danger,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (!await _disconnectSessionsForProjectIdChange()) {
      return;
    }
    await ref
        .read(walletConnectProjectIdSettingProvider.notifier)
        .deleteCustomProjectId();
    final applied =
        await ref.read(walletConnectControllerProvider.notifier).reconfigure();
    if (mounted) {
      _showMessage(
        applied
            ? setting.buildProjectId.isEmpty
                ? context.t.advanced.walletConnectProjectIdDeletedWithoutBuild
                : context.t.advanced.walletConnectProjectIdDeleted
            : context.t.advanced.walletConnectProjectIdApplyFailed,
      );
    }
  }

  Future<bool> _disconnectSessionsForProjectIdChange() async {
    final state = ref.read(walletConnectControllerProvider);
    if (state.sessions.isEmpty) {
      return true;
    }
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.walletConnectProjectIdDisconnectTitle,
      content: Text(
        context.t.advanced.walletConnectProjectIdDisconnectBody,
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmCallback: () => Navigator.of(context).pop(true),
      confirmKey: const Key('walletConnectProjectIdDisconnectConfirm'),
      confirmVariant: AppDialogActionVariant.danger,
    );
    if (confirmed != true) {
      return false;
    }
    try {
      await ref.read(walletConnectControllerProvider.notifier).disconnectAll();
      return true;
    } catch (_) {
      if (mounted) {
        _showMessage(
          context.t.advanced.walletConnectProjectIdDisconnectFailed,
        );
      }
      return false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disconnect(WalletConnectSession session) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.walletConnectDisconnectTitle,
      content: Text(context.t.advanced.walletConnectDisconnectBody),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmCallback: () => Navigator.of(context).pop(true),
      confirmTitle: context.t.advanced.walletConnectDisconnect,
      confirmKey: const Key('walletConnectDisconnectConfirm'),
      confirmVariant: AppDialogActionVariant.danger,
    );
    if (confirmed == true) {
      await ref
          .read(walletConnectControllerProvider.notifier)
          .disconnect(session.topic);
    }
  }

  Future<void> _disconnectAll() async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.walletConnectDisconnectAllTitle,
      content: Text(context.t.advanced.walletConnectDisconnectAllBody),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmCallback: () => Navigator.of(context).pop(true),
      confirmVariant: AppDialogActionVariant.danger,
    );
    if (confirmed == true) {
      await ref.read(walletConnectControllerProvider.notifier).disconnectAll();
    }
  }
}

final class _ProjectIdInputDialog extends StatefulWidget {
  const _ProjectIdInputDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ProjectIdInputDialog> createState() => _ProjectIdInputDialogState();
}

final class _ProjectIdInputDialogState extends State<_ProjectIdInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: context.t.advanced.walletConnectProjectIdInputTitle,
      content: TextField(
        key: const Key('walletConnectProjectIdInput'),
        controller: _controller,
        autocorrect: false,
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: context.t.advanced.walletConnectProjectIdInputHint,
        ),
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmCallback: () => Navigator.of(context).pop(_controller.text),
      confirmTitle: context.t.advanced.walletConnectProjectIdSet,
      confirmKey: const Key('walletConnectProjectIdSave'),
    );
  }
}

final class _ProjectIdCard extends StatelessWidget {
  const _ProjectIdCard({
    required this.setting,
    required this.onSet,
    required this.onDelete,
  });

  final WalletConnectProjectIdSettingState setting;
  final VoidCallback onSet;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final source = switch (setting.source) {
      WalletConnectProjectIdSource.custom =>
        context.t.advanced.walletConnectProjectIdSourceCustom,
      WalletConnectProjectIdSource.build =>
        context.t.advanced.walletConnectProjectIdSourceBuild,
      WalletConnectProjectIdSource.missing =>
        context.t.advanced.walletConnectProjectIdSourceMissing,
    };
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.key),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t.advanced.walletConnectProjectId,
                  style: context.appTextStyles.titleMedium,
                ),
              ),
              Text(source, style: context.appTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          if (setting.effectiveProjectId.isNotEmpty)
            SelectableText(
              _maskProjectId(setting.effectiveProjectId),
              style: context.appTextStyles.bodyLarge,
            )
          else
            Text(source, style: context.appTextStyles.bodyLarge),
          const SizedBox(height: 8),
          Text(
            context.t.advanced.walletConnectProjectIdDescription,
            style: context.appTextStyles.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onDelete != null)
                TextButton.icon(
                  key: const Key('walletConnectProjectIdDelete'),
                  onPressed: onDelete,
                  icon: const Icon(AppIcons.delete),
                  label: Text(
                    context.t.advanced.walletConnectProjectIdDelete,
                  ),
                ),
              TextButton.icon(
                key: const Key('walletConnectProjectIdSet'),
                onPressed: onSet,
                icon: Icon(
                  setting.customProjectId == null
                      ? AppIcons.add
                      : AppIcons.edit,
                ),
                label: Text(
                  setting.customProjectId == null
                      ? context.t.advanced.walletConnectProjectIdSet
                      : context.t.advanced.walletConnectProjectIdReplace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _maskProjectId(String value) {
  if (value.length <= 10) {
    return value;
  }
  return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sectionY),
      child: AppSectionCard(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Row(
          children: [
            const Icon(AppIcons.warning, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: context.appTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }
}

final class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onDisconnect});

  final WalletConnectSession session;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final domain = Uri.tryParse(session.peer.url)?.host ?? session.peer.url;
    final networks = session.namespaces.values
        .expand((namespace) => namespace.chains)
        .map((chain) => chain.toString())
        .join(', ');
    final methods = session.namespaces.values
        .expand((namespace) => namespace.methods)
        .toSet()
        .join(', ');
    final accounts = session.namespaces.values
        .expand((namespace) => namespace.accounts)
        .map((account) => account.toString())
        .toSet()
        .join(', ');
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WalletConnectPeerAvatar(peer: session.peer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.peer.name,
                      style: context.appTextStyles.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      domain,
                      style: context.appTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (networks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${context.t.advanced.walletConnectNetworks}: $networks',
              style: context.appTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (methods.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${context.t.advanced.walletConnectMethods}: $methods',
              style: context.appTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${context.t.advanced.walletConnectAccounts}: $accounts',
              style: context.appTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            context.t.advanced.walletConnectExpires(
              date: _formatDate(session.expiry),
            ),
            style: context.appTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: Key('walletConnectDisconnect-${session.topic}'),
              onPressed: onDisconnect,
              icon: const Icon(AppIcons.linkOff),
              label: Text(context.t.advanced.walletConnectDisconnect),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
