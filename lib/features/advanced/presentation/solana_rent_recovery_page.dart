import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_picker_field.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../../browser/presentation/dapp_browser_page.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/solana_rent_recovery_controller.dart';
import '../domain/solana_rent_recovery_models.dart';

final class SolanaRentRecoveryPage extends ConsumerStatefulWidget {
  const SolanaRentRecoveryPage({super.key});

  @override
  ConsumerState<SolanaRentRecoveryPage> createState() =>
      _SolanaRentRecoveryPageState();
}

final class _SolanaRentRecoveryPageState
    extends ConsumerState<SolanaRentRecoveryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(solanaRentRecoveryControllerProvider.future);
      if (!mounted) {
        return;
      }
      await ref.read(solanaRentRecoveryControllerProvider.notifier).scan();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(solanaRentRecoveryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.advanced.solanaRentRecovery),
        actions: [
          asyncState.when(
            data: (state) => _RefreshAction(
              isBusy: state.status == SolanaRentRecoveryStatus.scanning ||
                  state.status == SolanaRentRecoveryStatus.submitting,
              onPressed: () => ref
                  .read(solanaRentRecoveryControllerProvider.notifier)
                  .scan(),
            ),
            error: (_, _) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _FatalError(
            message: context.t.advanced.solanaRentScanFailed,
            onRetry: () => ref.invalidate(
              solanaRentRecoveryControllerProvider,
            ),
          ),
          data: (state) => _RecoveryContent(
            scrollController: _scrollController,
            state: state,
            onSelectWallet: () => _selectWallet(state),
            onSelectNetwork: () => _selectNetwork(state),
            onToggleAccount: (address) => ref
                .read(solanaRentRecoveryControllerProvider.notifier)
                .toggleAccount(address),
          ),
        ),
      ),
      bottomNavigationBar: asyncState.value == null
          ? null
          : _RecoveryBottomBar(
              state: asyncState.requireValue,
              onRecover: () => _confirmAndRecover(asyncState.requireValue),
            ),
    );
  }

  Future<void> _selectWallet(SolanaRentRecoveryState state) async {
    final selected = await showAppActionSheet<WalletAccount>(
      context,
      title: context.t.advanced.solanaRentWallet,
      actions: state.wallets
          .map(
            (wallet) => AppActionSheetAction(
              value: wallet,
              title: wallet.name,
              subtitle: _shortAddress(wallet.solanaAddress),
              icon: AppIcons.wallet,
              isSelected: wallet.id == state.selectedWalletId,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null || selected.id == state.selectedWalletId) {
      return;
    }
    final controller = ref.read(solanaRentRecoveryControllerProvider.notifier);
    controller.selectWallet(selected.id);
    await controller.scan();
  }

  Future<void> _selectNetwork(SolanaRentRecoveryState state) async {
    final selected = await showAppActionSheet<ChainConfig>(
      context,
      title: context.t.advanced.solanaRentNetwork,
      actions: state.networks
          .map(
            (network) => AppActionSheetAction(
              value: network,
              title: network.name,
              subtitle: network.chainId,
              icon: AppIcons.network,
              isSelected: network.id == state.selectedNetworkId,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted ||
        selected == null ||
        selected.id == state.selectedNetworkId) {
      return;
    }
    final controller = ref.read(solanaRentRecoveryControllerProvider.notifier);
    controller.selectNetwork(selected.id);
    await controller.scan();
  }

  Future<void> _confirmAndRecover(SolanaRentRecoveryState state) async {
    final wallet = state.selectedWallet;
    final network = state.selectedNetwork;
    final estimate = state.estimate;
    if (wallet == null ||
        network == null ||
        estimate == null ||
        state.selectedAccounts.isEmpty) {
      return;
    }
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.solanaRentConfirmTitle,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RiskNotice(
              level: RiskLevel.warning,
              message: context.t.advanced.solanaRentRisk,
            ),
            const SizedBox(height: 12),
            _ConfirmationLine(
              label: context.t.advanced.solanaRentNetwork,
              value: network.name,
            ),
            _ConfirmationLine(
              label: context.t.advanced.solanaRentReceivingWallet,
              value: wallet.name,
            ),
            _ConfirmationLine(
              label: context.t.advanced.solanaRentSelectedAccounts,
              value: state.selectedAccounts.length.toString(),
            ),
            _ConfirmationLine(
              label: context.t.advanced.solanaRentTotalRecoverable,
              value: _sol(estimate.totalRecoverableLamports),
            ),
            _ConfirmationLine(
              label: context.t.advanced.estimatedFee,
              value: _sol(estimate.networkFeeLamports),
            ),
            _ConfirmationLine(
              label: context.t.advanced.solanaRentNetRecoverable,
              value: _sol(estimate.netRecoverableLamports),
            ),
          ],
        ),
      ),
      confirmKey: const Key('confirmSolanaRentRecovery'),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: context.t.actions.confirm,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    SigningPasswordAuthorization? authorization;
    final cache = ref.read(sessionKeyCacheProvider);
    if (!cache.hasKey(wallet.id, now: DateTime.now().toUtc())) {
      authorization = await showSigningPasswordSheet(context);
      if (!mounted || authorization == null) {
        return;
      }
    }
    await ref.read(solanaRentRecoveryControllerProvider.notifier).recover(
          signingPassword: authorization?.password,
          rememberSigningPassword: authorization?.rememberPassword ?? true,
        );
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }
}

final class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.isBusy, required this.onPressed});

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('solanaRentRefreshButton'),
      tooltip: context.t.advanced.solanaRentRefresh,
      onPressed: isBusy ? null : onPressed,
      icon: isBusy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(AppIcons.refresh),
    );
  }
}

final class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({
    required this.scrollController,
    required this.state,
    required this.onSelectWallet,
    required this.onSelectNetwork,
    required this.onToggleAccount,
  });

  final ScrollController scrollController;
  final SolanaRentRecoveryState state;
  final VoidCallback onSelectWallet;
  final VoidCallback onSelectNetwork;
  final ValueChanged<String> onToggleAccount;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.advanced;
    final isScanning = state.status == SolanaRentRecoveryStatus.scanning;
    final isSubmitting = state.status == SolanaRentRecoveryStatus.submitting;
    final isBusy = isScanning || isSubmitting;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.pageX,
        AppSpacing.pageX,
        120,
      ),
      children: [
        AppPickerField(
          key: const Key('solanaRentWalletPicker'),
          label: strings.solanaRentWallet,
          value: state.selectedWallet?.name ?? strings.solanaRentNoWallet,
          leading: const Icon(AppIcons.wallet),
          onTap: state.wallets.isEmpty || isBusy ? null : onSelectWallet,
        ),
        const SizedBox(height: 12),
        AppPickerField(
          key: const Key('solanaRentNetworkPicker'),
          label: strings.solanaRentNetwork,
          value: state.selectedNetwork?.name ?? strings.solanaRentNoNetwork,
          leading: const Icon(AppIcons.solana),
          onTap: state.networks.isEmpty || isBusy ? null : onSelectNetwork,
        ),
        const SizedBox(height: AppSpacing.sectionY),
        RiskNotice(level: RiskLevel.info, message: strings.solanaRentRisk),
        const SizedBox(height: AppSpacing.sectionY),
        if (isScanning)
          AppSectionCard(
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(strings.solanaRentScanning),
              ],
            ),
          )
        else ...[
          if (isSubmitting) ...[
            AppSectionCard(
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(strings.solanaRentSubmitting)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
          ],
          _RecoverySummary(state: state),
          if (state.error != null) ...[
            const SizedBox(height: AppSpacing.sectionY),
            RiskNotice(
              level: RiskLevel.danger,
              message: _errorMessage(context, state.error!),
            ),
          ],
          const SizedBox(height: AppSpacing.sectionY),
          _AccountList(
            state: state,
            isEnabled: state.status == SolanaRentRecoveryStatus.ready,
            onToggleAccount: onToggleAccount,
          ),
          if (state.result != null) ...[
            const SizedBox(height: AppSpacing.sectionY),
            _RecoveryResultCard(state: state),
          ],
        ],
      ],
    );
  }
}

final class _RecoverySummary extends StatelessWidget {
  const _RecoverySummary({required this.state});

  final SolanaRentRecoveryState state;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.advanced;
    final estimate = state.estimate;
    return AppSectionCard(
      child: Column(
        children: [
          _SummaryLine(
            label: strings.solanaRentSelectedSummary,
            value: '${state.selectedAccounts.length} / '
                '${state.scanResult?.accounts.length ?? 0}',
          ),
          _SummaryLine(
            label: strings.solanaRentTotalRecoverable,
            value: _sol(estimate?.totalRecoverableLamports ?? BigInt.zero),
          ),
          _SummaryLine(
            label: strings.estimatedFee,
            value: _sol(estimate?.networkFeeLamports ?? BigInt.zero),
          ),
          _SummaryLine(
            label: strings.solanaRentNetRecoverable,
            value: _sol(estimate?.netRecoverableLamports ?? BigInt.zero),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

final class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.appTextStyles.bodySmall)),
          Text(value, style: context.appTextStyles.bodyLarge),
        ],
      ),
    );
  }
}

final class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.state,
    required this.isEnabled,
    required this.onToggleAccount,
  });

  final SolanaRentRecoveryState state;
  final bool isEnabled;
  final ValueChanged<String> onToggleAccount;

  @override
  Widget build(BuildContext context) {
    final accounts = state.scanResult?.accounts ?? const <SolanaRentAccount>[];
    if (accounts.isEmpty) {
      return AppSectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              const Icon(AppIcons.inbox, size: AppIconSize.prominent),
              const SizedBox(height: 10),
              Text(
                context.t.advanced.solanaRentNoAccounts,
                style: context.appTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t.advanced.solanaRentRecoverableAccounts,
          style: context.appTextStyles.titleMedium,
        ),
        const SizedBox(height: 10),
        ...accounts.map(
          (account) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AccountRow(
              account: account,
              isSelected:
                  state.selectedAccountAddresses.contains(account.address),
              onTap: isEnabled ? () => onToggleAccount(account.address) : null,
            ),
          ),
        ),
      ],
    );
  }
}

final class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  final SolanaRentAccount account;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final program = switch (account.program) {
      SolanaRentTokenProgram.splToken => context.t.advanced.solanaRentSplToken,
      SolanaRentTokenProgram.token2022 =>
        context.t.advanced.solanaRentToken2022,
    };
    return Material(
      key: Key('solanaRentAccount-${account.address}'),
      color: context.appColors.surface,
      borderRadius: AppRadius.mediumBorder,
      child: InkWell(
        borderRadius: AppRadius.mediumBorder,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.appColors.border,
            ),
            borderRadius: AppRadius.mediumBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: onTap == null ? null : (_) => onTap!(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortAddress(account.address),
                        style: context.appTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$program · ${_shortAddress(account.mintAddress)}',
                        style: context.appTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_sol(account.recoverableLamports)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _RecoveryBottomBar extends StatelessWidget {
  const _RecoveryBottomBar({required this.state, required this.onRecover});

  final SolanaRentRecoveryState state;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final isSubmitting = state.status == SolanaRentRecoveryStatus.submitting;
    final canRecover = state.status == SolanaRentRecoveryStatus.ready &&
        state.estimate != null &&
        state.selectedAccounts.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageX),
        child: AppButton.primary(
          key: const Key('solanaRentRecoveryButton'),
          label: context.t.advanced.solanaRentStartRecovery,
          onPressed: canRecover ? onRecover : null,
          child: isSubmitting
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(context.t.advanced.solanaRentRecovering),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

final class _RecoveryResultCard extends StatelessWidget {
  const _RecoveryResultCard({required this.state});

  final SolanaRentRecoveryState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final title = switch (state.status) {
      SolanaRentRecoveryStatus.success => context.t.advanced.solanaRentSuccess,
      SolanaRentRecoveryStatus.partialSuccess =>
        context.t.advanced.solanaRentPartialSuccess,
      _ => context.t.advanced.solanaRentFailed,
    };
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.status == SolanaRentRecoveryStatus.success
                    ? AppIcons.checkCircle
                    : AppIcons.warning,
                color: state.status == SolanaRentRecoveryStatus.success
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 10),
              Text(title, style: context.appTextStyles.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryLine(
            label: context.t.advanced.solanaRentRecoveredAccounts,
            value: result.completedAccountCount.toString(),
          ),
          _SummaryLine(
            label: context.t.advanced.solanaRentRecoveredAmount,
            value: _sol(result.recoveredLamports),
            isLast: true,
          ),
          if (result.signatures.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              context.t.advanced.solanaRentSignatures,
              style: context.appTextStyles.bodyLarge,
            ),
            const SizedBox(height: 8),
            ...result.signatures.indexed.map(
              (entry) => _SignatureRow(
                index: entry.$1,
                signature: entry.$2,
                network: state.selectedNetwork,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.index,
    required this.signature,
    required this.network,
  });

  final int index;
  final String signature;
  final ChainConfig? network;

  @override
  Widget build(BuildContext context) {
    final explorerUrl = network == null
        ? null
        : Uri.https(
            'solscan.io',
            '/tx/$signature',
            network!.chainId == 'mainnet-beta'
                ? null
                : {'cluster': network!.chainId},
          ).toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(signature, style: context.appTextStyles.caption),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  key: Key('copySolanaRentSignature$index'),
                  label: context.t.advanced.solanaRentCopySignature,
                  height: 40,
                  icon: const Icon(AppIcons.copy),
                  onPressed: () => _copy(context),
                ),
              ),
              if (explorerUrl != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton.secondary(
                    key: Key('openSolanaRentSignature$index'),
                    label: context.t.advanced.solanaRentOpenSolscan,
                    height: 40,
                    icon: const Icon(AppIcons.externalLink),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DappBrowserPage(
                          initialUrl: explorerUrl,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: signature));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t.advanced.solanaRentSignatureCopied)),
    );
  }
}

final class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: context.appTextStyles.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: context.appTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

final class _FatalError extends StatelessWidget {
  const _FatalError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageX),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: context.t.actions.confirm,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

String _sol(BigInt lamports) => '${formatSolLamports(lamports)} SOL';

String _shortAddress(String address) {
  if (address.length <= 14) {
    return address;
  }
  return '${address.substring(0, 6)}…${address.substring(address.length - 6)}';
}

String _errorMessage(BuildContext context, SolanaRentRecoveryError error) {
  final strings = context.t.advanced;
  return switch (error) {
    SolanaRentRecoveryError.noWallet => strings.solanaRentNoWallet,
    SolanaRentRecoveryError.noNetwork => strings.solanaRentNoNetwork,
    SolanaRentRecoveryError.scanFailed => strings.solanaRentScanFailed,
    SolanaRentRecoveryError.simulationFailed =>
      strings.solanaRentSimulationFailed,
    SolanaRentRecoveryError.insufficientFeeBalance =>
      strings.solanaRentInsufficientFee,
    SolanaRentRecoveryError.noAccountsSelected =>
      strings.solanaRentSelectAccount,
    SolanaRentRecoveryError.walletLocked => strings.solanaRentWalletLocked,
    SolanaRentRecoveryError.signingKeyUnavailable =>
      strings.solanaRentSigningKeyUnavailable,
    SolanaRentRecoveryError.accountsChanged =>
      strings.solanaRentAccountsChanged,
    SolanaRentRecoveryError.recoveryFailed => strings.solanaRentRecoveryFailed,
  };
}
