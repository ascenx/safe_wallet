import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address_book/application/address_book_controller.dart';
import '../../assets/domain/asset_balance.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../../shared/utils/bitcoin_address.dart';
import '../../../shared/utils/sui_address.dart';
import '../domain/transaction_request.dart';

final transferDraftControllerProvider =
    NotifierProvider<TransferDraftController, TransferDraftState>(
  TransferDraftController.new,
);

enum TransferDraftValidationFailure {
  invalidAddress,
  invalidAmount,
  insufficientBalance,
  unavailableBalance,
  missingMemo,
}

final class TransferDraftValidationException implements Exception {
  const TransferDraftValidationException(this.failure);

  final TransferDraftValidationFailure failure;

  @override
  String toString() => 'TransferDraftValidationException($failure)';
}

final class TransferDraftState {
  const TransferDraftState({
    this.request,
    this.failure,
    this.prefilledRecipient,
  });

  const TransferDraftState.empty()
      : request = null,
        failure = null,
        prefilledRecipient = null;

  final TransactionRequest? request;
  final TransferDraftValidationFailure? failure;
  final String? prefilledRecipient;

  bool get canContinue => request != null && failure == null;
}

final class TransferDraftController extends Notifier<TransferDraftState> {
  @override
  TransferDraftState build() {
    ref.listen(selectedChainControllerProvider, (previous, next) {
      final previousChainId = previous?.value?.id;
      final nextChainId = next.value?.id;
      if (previousChainId != null &&
          nextChainId != null &&
          previousChainId != nextChainId) {
        state = const TransferDraftState.empty();
      }
    });
    return const TransferDraftState.empty();
  }

  void prefillRecipient(String recipient) {
    state = TransferDraftState(
      request: state.request,
      failure: state.failure,
      prefilledRecipient: recipient,
    );
  }

  TransactionRequest prepareRequest({
    required ChainConfig chain,
    required AssetBalance asset,
    required String recipient,
    required String amount,
    String? memo,
  }) {
    final trimmedRecipient = recipient.trim();
    if (!_isValidRecipientAddress(trimmedRecipient, chain)) {
      _fail(TransferDraftValidationFailure.invalidAddress);
    }
    final normalizedRecipient = chain.chainType == ChainType.sui
        ? normalizeSuiAddressInput(trimmedRecipient)!
        : trimmedRecipient;

    final rawBalance = _rawBalance(asset);
    if (rawBalance == null) {
      _fail(TransferDraftValidationFailure.unavailableBalance);
    }

    final amountInBaseUnits = _parseTokenAmount(
      amount,
      decimals: asset.token.decimals,
    );
    if (amountInBaseUnits == null || amountInBaseUnits <= BigInt.zero) {
      _fail(TransferDraftValidationFailure.invalidAmount);
    }
    if (amountInBaseUnits > rawBalance) {
      _fail(TransferDraftValidationFailure.insufficientBalance);
    }

    final normalizedMemo = _blankToNull(memo);
    if (asset.token.requiresMemo && normalizedMemo == null) {
      _fail(TransferDraftValidationFailure.missingMemo);
    }

    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: asset.token.symbol,
      toAddress: normalizedRecipient,
      amount: amount.trim(),
      amountInBaseUnits: amountInBaseUnits.toString(),
      tokenDecimals: asset.token.decimals,
      memo: normalizedMemo,
      transactionType: _transactionType(chain, asset),
      tokenContractAddress: asset.token.contractAddress,
    );
    state = TransferDraftState(request: request);
    return request;
  }

  Never _fail(TransferDraftValidationFailure failure) {
    state = TransferDraftState(failure: failure);
    throw TransferDraftValidationException(failure);
  }

  BigInt? _rawBalance(AssetBalance asset) {
    if (asset.status != AssetBalanceStatus.loaded || asset.balance == null) {
      return null;
    }
    return BigInt.tryParse(asset.balance!);
  }

  TransactionType _transactionType(ChainConfig chain, AssetBalance asset) {
    return switch (chain.chainType) {
      ChainType.bitcoin => TransactionType.bitcoinTransfer,
      ChainType.tron when asset.token.contractAddress != null =>
        TransactionType.trc20Transfer,
      ChainType.tron => TransactionType.nativeTransfer,
      ChainType.solana => TransactionType.solTransfer,
      ChainType.sui => TransactionType.suiTransfer,
      ChainType.evm when asset.token.contractAddress != null =>
        TransactionType.erc20Transfer,
      ChainType.evm => TransactionType.nativeTransfer,
    };
  }
}

bool _isValidRecipientAddress(String address, ChainConfig chain) {
  return switch (chain.chainType) {
    ChainType.bitcoin => isBitcoinAddressForNetwork(
        address,
        isTestnet: chain.isTestnet,
      ),
    _ => isValidAddressForChainType(address, chain.chainType),
  };
}

BigInt? _parseTokenAmount(String amount, {required int decimals}) {
  final trimmed = amount.trim();
  if (trimmed.isEmpty || trimmed.startsWith('-') || decimals < 0) {
    return null;
  }
  final parts = trimmed.split('.');
  if (parts.length > 2) {
    return null;
  }

  final whole = parts[0].isEmpty ? '0' : parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';
  final digitsOnly = RegExp(r'^\d+$');
  if (!digitsOnly.hasMatch(whole)) {
    return null;
  }
  if (fraction.isNotEmpty && !digitsOnly.hasMatch(fraction)) {
    return null;
  }
  if (fraction.length > decimals) {
    return null;
  }

  final base = BigInt.from(10).pow(decimals);
  final wholeUnits = BigInt.parse(whole) * base;
  final paddedFraction = fraction.padRight(decimals, '0');
  final fractionUnits =
      paddedFraction.isEmpty ? BigInt.zero : BigInt.parse(paddedFraction);
  return wholeUnits + fractionUnits;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
