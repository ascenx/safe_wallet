import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
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
import '../../chains/domain/block_explorer_url_builder.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/wrapped_native_controller.dart';
import '../domain/wrapped_native_models.dart';

final class WrappedNativePage extends ConsumerStatefulWidget {
  const WrappedNativePage({super.key});

  @override
  ConsumerState<WrappedNativePage> createState() => _WrappedNativePageState();
}

final class _WrappedNativePageState extends ConsumerState<WrappedNativePage> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(wrappedNativeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.advanced.wrappedNative),
        actions: [
          IconButton(
            key: const Key('wrappedNativeRefreshButton'),
            tooltip: context.t.advanced.wrappedNativeRefresh,
            onPressed: asyncState.value == null || _isBusy(asyncState.value!)
                ? null
                : () => ref
                      .read(wrappedNativeControllerProvider.notifier)
                      .refresh(),
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _FatalError(
            message: context.t.advanced.wrappedNativeBalanceFailed,
            onRetry: () => ref.invalidate(wrappedNativeControllerProvider),
          ),
          data: (state) => _body(state),
        ),
      ),
    );
  }

  Widget _body(WrappedNativeState state) {
    final config = state.config;
    if (config == null) {
      return _FatalError(
        message: context.t.advanced.wrappedNativeNoNetwork,
        onRetry: () => ref.invalidate(wrappedNativeControllerProvider),
      );
    }
    final busy = _isBusy(state);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageX),
      children: [
        AppPickerField(
          key: const Key('wrappedNativeWalletPicker'),
          label: context.t.advanced.wrappedNativeWallet,
          value:
              state.selectedWallet?.name ??
              context.t.advanced.wrappedNativeNoWallet,
          onTap: busy || state.wallets.isEmpty
              ? null
              : () => _selectWallet(state),
        ),
        const SizedBox(height: 12),
        AppPickerField(
          key: const Key('wrappedNativeNetworkPicker'),
          label: context.t.advanced.wrappedNativeNetwork,
          value:
              state.selectedNetwork?.name ??
              context.t.advanced.wrappedNativeNoNetwork,
          onTap: busy || state.networks.isEmpty
              ? null
              : () => _selectNetwork(state),
        ),
        const SizedBox(height: AppSpacing.sectionY),
        _BalanceCard(state: state, config: config),
        const SizedBox(height: AppSpacing.sectionY),
        TextField(
          key: const Key('wrappedNativeAmountInput'),
          controller: _amountController,
          enabled: !busy,
          autocorrect: false,
          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.t.advanced.wrappedNativeAmount,
            hintText: context.t.advanced.wrappedNativeAmountHint,
            suffixIcon: TextButton(
              key: const Key('wrappedNativeMaxButton'),
              onPressed: busy ? null : () => _setMax(config),
              child: Text(context.t.advanced.wrappedNativeMax),
            ),
            suffixText: state.operation == WrappedNativeOperation.wrap
                ? config.nativeSymbol
                : config.wrappedSymbol,
          ),
          onChanged: (_) => ref
              .read(wrappedNativeControllerProvider.notifier)
              .clearPreparation(),
        ),
        const SizedBox(height: 12),
        _OperationPicker(
          key: const Key('wrappedNativeOperationPicker'),
          fromSymbol: state.operation == WrappedNativeOperation.wrap
              ? config.nativeSymbol
              : config.wrappedSymbol,
          toSymbol: state.operation == WrappedNativeOperation.wrap
              ? config.wrappedSymbol
              : config.nativeSymbol,
          switchTooltip: state.operation == WrappedNativeOperation.wrap
              ? context.t.advanced.wrappedNativeUnwrap
              : context.t.advanced.wrappedNativeWrap,
          onTap: busy ? null : () => _toggleOperation(state.operation),
        ),
        const SizedBox(height: 12),
        RiskNotice(
          level: RiskLevel.warning,
          message: context.t.advanced.wrappedNativeRisk,
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage(state.error!),
            style: context.appTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (state.status == WrappedNativeStatus.preparing) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Text(
            context.t.advanced.wrappedNativePreparing,
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodySmall,
          ),
        ],
        if (state.status == WrappedNativeStatus.submitting) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Text(
            context.t.advanced.wrappedNativeSubmitting,
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodySmall,
          ),
        ],
        if (state.status == WrappedNativeStatus.success &&
            state.transactionHash != null) ...[
          const SizedBox(height: AppSpacing.sectionY),
          _SuccessCard(state: state),
        ],
        const SizedBox(height: AppSpacing.sectionY),
        AppButton.primary(
          key: const Key('wrappedNativeReviewButton'),
          label: context.t.advanced.wrappedNativeReview,
          onPressed: busy || state.selectedWallet == null
              ? null
              : () => _review(state, config),
        ),
      ],
    );
  }

  void _toggleOperation(WrappedNativeOperation operation) {
    _amountController.clear();
    ref
        .read(wrappedNativeControllerProvider.notifier)
        .selectOperation(
          operation == WrappedNativeOperation.wrap
              ? WrappedNativeOperation.unwrap
              : WrappedNativeOperation.wrap,
        );
  }

  Future<void> _selectWallet(WrappedNativeState state) async {
    final network = state.selectedNetwork;
    final wallets = network == null
        ? const <WalletAccount>[]
        : state.wallets
              .where(
                (wallet) => wallet
                    .addressForChainType(network.chainType)
                    .trim()
                    .isNotEmpty,
              )
              .toList(growable: false);
    final selected = await showAppActionSheet<WalletAccount>(
      context,
      title: context.t.advanced.wrappedNativeWallet,
      actions: wallets
          .map(
            (wallet) => AppActionSheetAction(
              value: wallet,
              title: wallet.name,
              subtitle: wallet.addressForChainType(
                state.selectedNetwork?.chainType ?? ChainType.evm,
              ),
              icon: AppIcons.wallet,
              isSelected: wallet.id == state.selectedWalletId,
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || selected == null || selected.id == state.selectedWalletId) {
      return;
    }
    _amountController.clear();
    await ref
        .read(wrappedNativeControllerProvider.notifier)
        .selectWallet(selected.id);
  }

  Future<void> _selectNetwork(WrappedNativeState state) async {
    final selected = await showAppActionSheet<ChainConfig>(
      context,
      title: context.t.advanced.wrappedNativeNetwork,
      actions: state.networks
          .map(
            (network) => AppActionSheetAction(
              value: network,
              title: network.name,
              subtitle: wrappedNativeConfigFor(network)?.wrappedSymbol,
              icon: network.chainType == ChainType.solana
                  ? AppIcons.solana
                  : AppIcons.network,
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
    _amountController.clear();
    await ref
        .read(wrappedNativeControllerProvider.notifier)
        .selectNetwork(selected.id);
  }

  Future<void> _setMax(WrappedNativeConfig config) async {
    final maximum = await ref
        .read(wrappedNativeControllerProvider.notifier)
        .prepareMaximum();
    if (!mounted || maximum == null) return;
    _amountController.text = formatWrappedNativeAmount(
      maximum,
      decimals: config.decimals,
    );
    _amountController.selection = TextSelection.collapsed(
      offset: _amountController.text.length,
    );
  }

  Future<void> _review(
    WrappedNativeState state,
    WrappedNativeConfig config,
  ) async {
    final amount = parseWrappedNativeAmount(
      _amountController.text,
      decimals: config.decimals,
    );
    if (amount == null || amount <= BigInt.zero) {
      await ref
          .read(wrappedNativeControllerProvider.notifier)
          .prepareBaseUnits(BigInt.zero);
      return;
    }
    if (state.preparation == null || state.amountInBaseUnits != amount) {
      await ref
          .read(wrappedNativeControllerProvider.notifier)
          .prepareBaseUnits(amount);
    }
    if (!mounted) return;
    final prepared = ref.read(wrappedNativeControllerProvider).value;
    if (prepared?.preparation == null || prepared?.error != null) return;
    await _confirm(prepared!, config);
  }

  Future<void> _confirm(
    WrappedNativeState state,
    WrappedNativeConfig config,
  ) async {
    final amount = state.amountInBaseUnits!;
    final summary = state.preparation!;
    final amountText = formatWrappedNativeAmount(
      amount,
      decimals: config.decimals,
    );
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.wrappedNativeConfirmTitle,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RiskNotice(
              level: RiskLevel.warning,
              message: context.t.advanced.wrappedNativeRisk,
            ),
            const SizedBox(height: 12),
            _ConfirmationLine(
              label: context.t.advanced.wrappedNativeNetwork,
              value: state.selectedNetwork!.name,
            ),
            _ConfirmationLine(
              label: context.t.advanced.wrappedNativeFrom,
              value:
                  '$amountText ${state.operation == WrappedNativeOperation.wrap ? config.nativeSymbol : config.wrappedSymbol}',
            ),
            _ConfirmationLine(
              label: context.t.advanced.wrappedNativeTo,
              value:
                  '$amountText ${state.operation == WrappedNativeOperation.wrap ? config.wrappedSymbol : config.nativeSymbol}',
            ),
            _ConfirmationLine(
              label: context.t.advanced.wrappedNativeNetworkFee,
              value:
                  '${formatWrappedNativeAmount(summary.networkFeeInBaseUnits, decimals: config.decimals)} ${config.nativeSymbol}',
            ),
            if (summary.accountRentInBaseUnits > BigInt.zero)
              _ConfirmationLine(
                label: context.t.advanced.wrappedNativeRent,
                value:
                    '${formatWrappedNativeAmount(summary.accountRentInBaseUnits, decimals: config.decimals)} ${config.nativeSymbol}',
              ),
          ],
        ),
      ),
      confirmKey: const Key('confirmWrappedNative'),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: state.operation == WrappedNativeOperation.wrap
          ? context.t.advanced.wrappedNativeConfirmWrap
          : context.t.advanced.wrappedNativeConfirmUnwrap,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    if (!mounted || confirmed != true) return;
    SigningPasswordAuthorization? authorization;
    final wallet = state.selectedWallet!;
    final cache = ref.read(sessionKeyCacheProvider);
    if (!cache.hasKey(wallet.id, now: DateTime.now().toUtc())) {
      authorization = await showSigningPasswordSheet(context);
      if (!mounted || authorization == null) return;
    }
    await ref
        .read(wrappedNativeControllerProvider.notifier)
        .submit(
          signingPassword: authorization?.password,
          rememberSigningPassword: authorization?.rememberPassword ?? true,
        );
  }

  String _errorMessage(WrappedNativeError error) => switch (error) {
    WrappedNativeError.noWallet => context.t.advanced.wrappedNativeNoWallet,
    WrappedNativeError.noNetwork => context.t.advanced.wrappedNativeNoNetwork,
    WrappedNativeError.invalidAmount =>
      context.t.advanced.wrappedNativeInvalidAmount,
    WrappedNativeError.insufficientNativeBalance =>
      context.t.advanced.wrappedNativeInsufficientNative,
    WrappedNativeError.insufficientWrappedBalance =>
      context.t.advanced.wrappedNativeInsufficientWrapped,
    WrappedNativeError.balanceLoadFailed =>
      context.t.advanced.wrappedNativeBalanceFailed,
    WrappedNativeError.preparationFailed =>
      context.t.advanced.wrappedNativePreparationFailed,
    WrappedNativeError.walletLocked =>
      context.t.advanced.wrappedNativeWalletLocked,
    WrappedNativeError.signingKeyUnavailable =>
      context.t.advanced.wrappedNativeSigningKeyUnavailable,
    WrappedNativeError.submissionFailed =>
      context.t.advanced.wrappedNativeSubmissionFailed,
  };

  bool _isBusy(WrappedNativeState state) =>
      state.status == WrappedNativeStatus.loading ||
      state.status == WrappedNativeStatus.preparing ||
      state.status == WrappedNativeStatus.submitting;
}

final class _OperationPicker extends StatelessWidget {
  const _OperationPicker({
    required this.fromSymbol,
    required this.toSymbol,
    required this.switchTooltip,
    required this.onTap,
    super.key,
  });

  final String fromSymbol;
  final String toSymbol;
  final String switchTooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = '$fromSymbol → $toSymbol';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: value,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.mediumBorder,
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(enabled: onTap != null, contentPadding: EdgeInsets.all(12).copyWith(right: 0)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: context.appTextStyles.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('wrappedNativeOperationSwitchButton'),
                  tooltip: switchTooltip,
                  onPressed: onTap,
                  padding: EdgeInsets.zero,
                  icon: Icon(AppIcons.swap, size: 24, color: colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state, required this.config});

  final WrappedNativeState state;
  final WrappedNativeConfig config;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        children: [
          _BalanceLine(
            label: context.t.advanced.wrappedNativeBalance,
            value:
                '${formatWrappedNativeAmount(state.nativeBalanceInBaseUnits, decimals: config.decimals)} ${config.nativeSymbol}',
          ),
          const SizedBox(height: 12),
          _BalanceLine(
            label: context.t.advanced.wrappedNativeTokenBalance,
            value:
                '${formatWrappedNativeAmount(state.wrappedBalanceInBaseUnits, decimals: config.decimals)} ${config.wrappedSymbol}',
          ),
        ],
      ),
    );
  }
}

final class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: context.appTextStyles.bodySmall)),
      Text(value, style: context.appTextStyles.bodyLarge),
    ],
  );
}

final class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.state});

  final WrappedNativeState state;

  @override
  Widget build(BuildContext context) {
    final network = state.selectedNetwork!;
    final hash = state.transactionHash!;
    final explorerUrl = buildBlockExplorerTransactionUrl(
      chainType: network.chainType,
      chainId: network.chainId,
      transactionHash: hash,
      blockExplorerUrl: network.blockExplorerUrl,
    );
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.checkCircle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.operation == WrappedNativeOperation.wrap
                      ? context.t.advanced.wrappedNativeSuccessWrap
                      : context.t.advanced.wrappedNativeSuccessUnwrap,
                  style: context.appTextStyles.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t.advanced.wrappedNativeTransactionHash,
            style: context.appTextStyles.bodySmall,
          ),
          const SizedBox(height: 4),
          SelectableText(hash, style: context.appTextStyles.caption),
          if (explorerUrl != null) ...[
            const SizedBox(height: 12),
            AppButton.secondary(
              key: const Key('openWrappedNativeExplorer'),
              label: context.t.advanced.wrappedNativeViewExplorer,
              icon: const Icon(AppIcons.externalLink),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DappBrowserPage(initialUrl: explorerUrl),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: context.appTextStyles.bodySmall)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.appTextStyles.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

final class _FatalError extends StatelessWidget {
  const _FatalError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.pageX),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.error, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: context.t.advanced.wrappedNativeRefresh,
            onPressed: onRetry,
          ),
        ],
      ),
    ),
  );
}
