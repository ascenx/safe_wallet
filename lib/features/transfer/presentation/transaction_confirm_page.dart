import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/utils/token_amount.dart';
import '../../../shared/security/address_poisoning_detector.dart';
import '../../../shared/errors/transfer_error.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/fee_estimate_provider.dart';
import '../application/transaction_broadcast_controller.dart';
import '../application/transaction_confirm_controller.dart';
import '../domain/transaction_request.dart';
import 'transaction_result_page.dart';
import 'transfer_fee_picker_sheet.dart';

final class TransactionConfirmPage extends ConsumerStatefulWidget {
  const TransactionConfirmPage({
    required this.chain,
    required this.rpcNode,
    required this.account,
    required this.request,
    required this.feeEstimate,
    required this.confirmation,
    this.historicalRecipients,
    super.key,
  });

  final ChainConfig chain;
  final RpcNode rpcNode;
  final WalletAccount account;
  final TransactionRequest request;
  final FeeEstimate feeEstimate;
  final TransactionConfirmation confirmation;
  final List<String>? historicalRecipients;

  @override
  ConsumerState<TransactionConfirmPage> createState() =>
      _TransactionConfirmPageState();
}

final class _TransactionConfirmPageState
    extends ConsumerState<TransactionConfirmPage> {
  late FeeEstimate _feeEstimate;
  late TransactionConfirmation _confirmation;
  late TransactionRequest _request;
  late bool _isMaxTransfer;

  @override
  void initState() {
    super.initState();
    _feeEstimate = widget.feeEstimate;
    _confirmation = widget.confirmation;
    _request = widget.request;
    _isMaxTransfer = _usesMaximumBalance(
      request: widget.request,
      feeEstimate: widget.feeEstimate,
      availableBalance: widget.confirmation.availableBalanceInBaseUnits,
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmation = _confirmation;
    final riskWarnings = _riskWarnings(confirmation);
    return Scaffold(
      appBar: AppBar(title: Text(t.transfer.confirmTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
          children: [
            _SummaryCard(
              children: [
                _FieldRow(
                  label: t.transfer.chain,
                  value: confirmation.chainName,
                ),
                _FieldRow(
                  label: t.transfer.from,
                  value: confirmation.fromAddress,
                  isAddress: true,
                ),
                _FieldRow(
                  label: t.transfer.to,
                  value: confirmation.toAddress,
                  isAddress: true,
                ),
                _FieldRow(
                  label: t.transfer.token,
                  value: confirmation.assetSymbol,
                ),
                _FieldRow(label: t.transfer.amount, value: confirmation.amount),
                _FieldRow(
                  label: confirmation.maximumFee == null
                      ? t.transfer.fee
                      : t.transfer.estimatedFee,
                  value: '${confirmation.fee} ${confirmation.feeAssetSymbol}',
                  key: const Key('transactionFeePickerButton'),
                  onTap: _canEditFee ? _editFee : null,
                ),
                if (confirmation.maximumFee != null)
                  _FieldRow(
                    label: t.transfer.maximumFee,
                    value:
                        '${confirmation.maximumFee} ${confirmation.feeAssetSymbol}',
                  ),
                _FieldRow(
                  label: t.transfer.feeModel,
                  value: _feeModelLabel(confirmation.feeModel),
                ),
                if (confirmation.maxFeePerGasWei != null)
                  _FieldRow(
                    label: t.transfer.maxFeePerGas,
                    value: _weiValue(confirmation.maxFeePerGasWei!),
                  ),
                if (confirmation.maxPriorityFeePerGasWei != null)
                  _FieldRow(
                    label: t.transfer.maxPriorityFeePerGas,
                    value: _weiValue(confirmation.maxPriorityFeePerGasWei!),
                  ),
                if (confirmation.gasPriceWei != null)
                  _FieldRow(
                    label: t.transfer.gasPrice,
                    value: _weiValue(confirmation.gasPriceWei!),
                  ),
                if (confirmation.priorityFee != null)
                  _FieldRow(
                    label: t.transfer.priorityFeeSol,
                    value: '${confirmation.priorityFee} SOL',
                  ),
                if (confirmation.bitcoinFeeRate != null)
                  _FieldRow(
                    label: t.transfer.bitcoinFeeRate,
                    value:
                        '${_formatRate(confirmation.bitcoinFeeRate!)} sat/vB',
                  ),
                if (confirmation.confirmationBlocks != null)
                  _FieldRow(
                    label: t.transfer.estimatedConfirmation,
                    value:
                        '${t.transfer.approximately} ${confirmation.confirmationBlocks} ${t.transfer.blocks}',
                  ),
                if (confirmation.feeLimit != null)
                  _FieldRow(
                    label: t.transfer.tronFeeLimit,
                    value: '${confirmation.feeLimit} TRX',
                  ),
                _FieldRow(
                  label: t.transfer.totalDeduction,
                  value: confirmation.totalDeduction,
                ),
                if (confirmation.tokenContractAddress != null)
                  _FieldRow(
                    label: t.transfer.contractAddress,
                    value: confirmation.tokenContractAddress!,
                    isAddress: true,
                  ),
                if (confirmation.memo != null)
                  _FieldRow(
                    label: t.transfer.memoLabel,
                    value: confirmation.memo!,
                  ),
              ],
            ),
            if (riskWarnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sectionY),
              _RiskCard(warnings: riskWarnings),
            ],
            const SizedBox(height: 24),
            AppButton.primary(
              label: t.actions.submit,
              onPressed: () => _confirm(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _riskWarnings(TransactionConfirmation confirmation) {
    final historicalRecipients = widget.historicalRecipients;
    if (historicalRecipients == null) {
      return confirmation.riskWarnings;
    }
    final addressRisk = detectAddressRisk(
      recipient: confirmation.toAddress,
      historicalRecipients: historicalRecipients,
    );
    return [
      ...confirmation.riskWarnings,
      if (addressRisk.kind == AddressRiskKind.newRecipient)
        t.transfer.newRecipientWarning,
      if (addressRisk.kind == AddressRiskKind.lookalike)
        t.transfer.lookalikeRecipientWarning(
          address: addressRisk.similarAddress!,
        ),
    ];
  }

  String _feeModelLabel(FeeModel model) {
    return switch (model) {
      FeeModel.eip1559 => t.transfer.feeModelEip1559,
      FeeModel.legacy => t.transfer.feeModelLegacy,
      FeeModel.bitcoin => t.transfer.feeModelBitcoin,
      FeeModel.tron => t.transfer.feeModelTron,
      FeeModel.solana => t.transfer.feeModelSolana,
      FeeModel.sui => t.transfer.feeModelSui,
    };
  }

  String _weiValue(String value) {
    final wei = BigInt.parse(value);
    final whole = wei ~/ BigInt.from(1000000000);
    final fraction = (wei % BigInt.from(1000000000))
        .toString()
        .padLeft(9, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    final gwei = fraction.isEmpty ? '$whole' : '$whole.$fraction';
    return '$gwei Gwei';
  }

  String _formatRate(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  bool get _canEditFee {
    return widget.chain.chainType != ChainType.tron ||
        _request.transactionType == TransactionType.trc20Transfer;
  }

  Future<void> _editFee() async {
    final selected = await showTransferFeePickerSheet(
      context,
      feeEstimate: _feeEstimate,
      request: _request,
    );
    if (!mounted || selected == null) {
      return;
    }
    try {
      var request = _request;
      final availableBalance = _confirmation.availableBalanceInBaseUnits;
      if (_isMaxTransfer && availableBalance != null) {
        final maxAmount = availableBalance - selected.feeInBaseUnits;
        if (maxAmount <= BigInt.zero) {
          throw const TransferError.insufficientBalance();
        }
        request = request.withAmount(
          amount: formatTokenAmount(
            maxAmount,
            decimals: request.tokenDecimals ?? _nativeDecimals(widget.chain),
          ),
          amountInBaseUnits: maxAmount,
        );
      }
      final confirmation = ref
          .read(transactionConfirmControllerProvider)
          .buildConfirmation(
            chain: widget.chain,
            account: widget.account,
            request: request,
            feeEstimate: selected,
            availableBalanceInBaseUnits:
                _confirmation.availableBalanceInBaseUnits,
          );
      setState(() {
        _feeEstimate = selected;
        _confirmation = confirmation;
        _request = request;
      });
    } on TransferError catch (error) {
      if (error.code == 'insufficient_balance' && mounted) {
        AppToast.show(
          context,
          message: t.transfer.insufficientBalance,
          variant: AppToastVariant.error,
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final cache = ref.read(sessionKeyCacheProvider);
    final hasSigningKey = cache.hasKey(
      widget.account.id,
      now: ref.read(transactionBroadcastClockProvider)(),
    );
    SigningPasswordAuthorization? authorization;
    if (!hasSigningKey) {
      authorization = await showSigningPasswordSheet(context);
      if (!context.mounted || authorization == null) {
        return;
      }
    }

    final broadcastRequest = TransactionBroadcastRequest(
      chain: widget.chain,
      rpcNode: widget.rpcNode,
      account: widget.account,
      transaction: _request,
      feeEstimate: _feeEstimate,
    );
    final loadingDialog = AppDialog.showBuilder<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AppDialog(
          key: const Key('transactionSubmitLoadingDialog'),
          title: t.transactions.submitting,
          content: const Center(
            child: SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
          showCancel: false,
          showConfirm: false,
        ),
      ),
    );
    await ref
        .read(transactionBroadcastControllerProvider.notifier)
        .submit(
          broadcastRequest,
          signingPassword: authorization?.password,
          rememberSigningPassword: authorization?.rememberPassword ?? true,
        );
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    await loadingDialog;
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TransactionResultPage(request: broadcastRequest),
      ),
    );
  }

  bool _usesMaximumBalance({
    required TransactionRequest request,
    required FeeEstimate feeEstimate,
    required BigInt? availableBalance,
  }) {
    if (availableBalance == null ||
        request.tokenContractAddress != null ||
        request.assetSymbol != feeEstimate.feeAssetSymbol) {
      return false;
    }
    final amount = BigInt.tryParse(request.amountInBaseUnits ?? '');
    return amount != null &&
        amount + feeEstimate.feeInBaseUnits == availableBalance;
  }

  int _nativeDecimals(ChainConfig chain) {
    return switch (chain.chainType) {
      ChainType.evm => 18,
      ChainType.bitcoin => 8,
      ChainType.tron => 6,
      ChainType.solana => 9,
      ChainType.sui => 9,
    };
  }
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      borderRadius: AppRadius.largeBorder,
      child: Column(children: children),
    );
  }
}

final class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.isAddress = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool isAddress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label, style: context.appTextStyles.caption),
          ),
          Expanded(
            child: isAddress
                ? Text.rich(
                    highlightedAddressTextSpan(
                      value,
                      style: context.appTextStyles.bodySmall,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.end,
                  )
                : Text(
                    value,
                    style: context.appTextStyles.bodySmall,
                    textAlign: TextAlign.end,
                  ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(AppIcons.chevronRight, size: 18),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}

final class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return RiskNotice(
      level: RiskLevel.warning,
      message: [
        t.transfer.riskWarnings,
        for (final warning in warnings) _warningLabel(warning),
      ].join('\n'),
    );
  }

  String _warningLabel(String warning) {
    return switch (warning) {
      'legacy_fee_model' => t.transfer.riskLegacy,
      'erc20_contract_transfer' => t.transfer.riskErc20,
      _ => warning,
    };
  }
}
