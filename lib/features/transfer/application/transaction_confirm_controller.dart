import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors/transfer_error.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/domain/wallet_account.dart';
import '../domain/transaction_request.dart';
import 'fee_estimate_provider.dart';

final transactionConfirmControllerProvider =
    Provider<TransactionConfirmController>((ref) {
      return const TransactionConfirmController();
    });

final class TransactionConfirmController {
  const TransactionConfirmController();

  TransactionConfirmation buildConfirmation({
    required ChainConfig chain,
    required WalletAccount account,
    required TransactionRequest request,
    required FeeEstimate? feeEstimate,
    BigInt? availableBalanceInBaseUnits,
  }) {
    final estimate = feeEstimate;
    if (estimate == null) {
      throw const TransferError.feeEstimateFailed();
    }
    _validateNativeBalance(
      request: request,
      estimate: estimate,
      availableBalanceInBaseUnits: availableBalanceInBaseUnits,
    );

    return TransactionConfirmation(
      chainName: chain.name,
      fromAddress: _fromAddress(chain, account),
      toAddress: request.toAddress,
      assetSymbol: request.assetSymbol,
      amount: request.amount,
      amountInBaseUnits: request.amountInBaseUnits ?? request.amount,
      fee: _formatBaseUnits(
        estimate.estimatedFeeInBaseUnits,
        decimals: _nativeDecimals(chain.chainType),
      ),
      maximumFee: estimate.estimatedFeeInBaseUnits == estimate.feeInBaseUnits
          ? null
          : _formatBaseUnits(
              estimate.feeInBaseUnits,
              decimals: _nativeDecimals(chain.chainType),
            ),
      feeInBaseUnits: estimate.feeInBaseUnits.toString(),
      feeAssetSymbol: estimate.feeAssetSymbol,
      feeModel: estimate.model,
      maxFeePerGasWei: estimate.maxFeePerGasWei?.toString(),
      maxPriorityFeePerGasWei: estimate.maxPriorityFeePerGasWei?.toString(),
      gasPriceWei: estimate.gasPriceWei?.toString(),
      priorityFee: estimate.priorityFeeInBaseUnits == null
          ? null
          : _formatBaseUnits(
              estimate.priorityFeeInBaseUnits!,
              decimals: _nativeDecimals(chain.chainType),
            ),
      bitcoinFeeRate: estimate.satsPerVbyte,
      confirmationBlocks: estimate.confirmationBlocks,
      feeLimit: estimate.feeLimitSun == null
          ? null
          : _formatBaseUnits(estimate.feeLimitSun!, decimals: 6),
      totalDeduction: _totalDeduction(chain, request, estimate),
      availableBalanceInBaseUnits: availableBalanceInBaseUnits,
      tokenContractAddress: request.tokenContractAddress,
      memo: request.memo,
      riskWarnings: _riskWarnings(request, estimate),
    );
  }

  void _validateNativeBalance({
    required TransactionRequest request,
    required FeeEstimate estimate,
    required BigInt? availableBalanceInBaseUnits,
  }) {
    if (availableBalanceInBaseUnits == null ||
        request.tokenContractAddress != null ||
        request.assetSymbol != estimate.feeAssetSymbol) {
      return;
    }
    final amount = BigInt.tryParse(request.amountInBaseUnits ?? '');
    if (amount != null &&
        amount + estimate.feeInBaseUnits > availableBalanceInBaseUnits) {
      throw const TransferError.insufficientBalance();
    }
  }

  String _fromAddress(ChainConfig chain, WalletAccount account) {
    return switch (chain.chainType) {
      ChainType.evm => account.evmAddress,
      ChainType.bitcoin => account.btcAddress,
      ChainType.tron => account.tronAddress,
      ChainType.solana => account.solanaAddress,
      ChainType.sui => account.suiAddress,
    };
  }

  String _totalDeduction(
    ChainConfig chain,
    TransactionRequest request,
    FeeEstimate estimate,
  ) {
    final amount = BigInt.tryParse(request.amountInBaseUnits ?? '');
    if (amount != null && request.assetSymbol == estimate.feeAssetSymbol) {
      final decimals =
          request.tokenDecimals ?? _nativeDecimals(chain.chainType);
      final total = _formatBaseUnits(
        amount + estimate.feeInBaseUnits,
        decimals: decimals,
      );
      return '$total ${request.assetSymbol}';
    }
    final fee = _formatBaseUnits(
      estimate.feeInBaseUnits,
      decimals: _nativeDecimals(chain.chainType),
    );
    return '${request.amount} ${request.assetSymbol} + $fee '
        '${estimate.feeAssetSymbol}';
  }

  List<String> _riskWarnings(TransactionRequest request, FeeEstimate estimate) {
    return [
      if (request.transactionType == TransactionType.erc20Transfer ||
          request.transactionType == TransactionType.trc20Transfer)
        'erc20_contract_transfer',
      if (estimate.model == FeeModel.legacy) 'legacy_fee_model',
    ];
  }
}

int _nativeDecimals(ChainType chainType) {
  return switch (chainType) {
    ChainType.evm => 18,
    ChainType.bitcoin => 8,
    ChainType.tron => 6,
    ChainType.solana => 9,
    ChainType.sui => 9,
  };
}

String _formatBaseUnits(BigInt value, {required int decimals}) {
  if (decimals <= 0) {
    return value.toString();
  }
  final negative = value.isNegative;
  final absolute = value.abs();
  final base = BigInt.from(10).pow(decimals);
  final whole = absolute ~/ base;
  final fraction = (absolute % base)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final sign = negative ? '-' : '';
  return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
}

final class TransactionConfirmation {
  const TransactionConfirmation({
    required this.chainName,
    required this.fromAddress,
    required this.toAddress,
    required this.assetSymbol,
    required this.amount,
    required this.amountInBaseUnits,
    required this.fee,
    this.maximumFee,
    required this.feeInBaseUnits,
    required this.feeAssetSymbol,
    required this.feeModel,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.gasPriceWei,
    this.priorityFee,
    this.bitcoinFeeRate,
    this.confirmationBlocks,
    this.feeLimit,
    required this.totalDeduction,
    required this.riskWarnings,
    this.availableBalanceInBaseUnits,
    this.tokenContractAddress,
    this.memo,
  });

  final String chainName;
  final String fromAddress;
  final String toAddress;
  final String assetSymbol;
  final String amount;
  final String amountInBaseUnits;
  final String fee;
  final String? maximumFee;
  final String feeInBaseUnits;
  final String feeAssetSymbol;
  final FeeModel feeModel;
  final String? maxFeePerGasWei;
  final String? maxPriorityFeePerGasWei;
  final String? gasPriceWei;
  final String? priorityFee;
  final double? bitcoinFeeRate;
  final int? confirmationBlocks;
  final String? feeLimit;
  final String totalDeduction;
  final List<String> riskWarnings;
  final BigInt? availableBalanceInBaseUnits;
  final String? tokenContractAddress;
  final String? memo;
}
