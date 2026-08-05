import '../../chains/domain/chain_config.dart';

enum TransactionType {
  nativeTransfer,
  erc20Transfer,
  trc20Transfer,
  bitcoinTransfer,
  solTransfer,
  suiTransfer,
}

final class TransactionRequest {
  const TransactionRequest({
    required this.chainId,
    required this.chainType,
    required this.assetSymbol,
    required this.toAddress,
    required this.amount,
    required this.transactionType,
    this.amountInBaseUnits,
    this.tokenDecimals,
    this.memo,
    this.tokenContractAddress,
  });

  final String chainId;
  final ChainType chainType;
  final String assetSymbol;
  final String toAddress;
  final String amount;
  final TransactionType transactionType;
  final String? amountInBaseUnits;
  final int? tokenDecimals;
  final String? memo;
  final String? tokenContractAddress;

  TransactionRequest withAmount({
    required String amount,
    required BigInt amountInBaseUnits,
  }) {
    return TransactionRequest(
      chainId: chainId,
      chainType: chainType,
      assetSymbol: assetSymbol,
      toAddress: toAddress,
      amount: amount,
      transactionType: transactionType,
      amountInBaseUnits: amountInBaseUnits.toString(),
      tokenDecimals: tokenDecimals,
      memo: memo,
      tokenContractAddress: tokenContractAddress,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionRequest &&
            other.chainId == chainId &&
            other.chainType == chainType &&
            other.assetSymbol == assetSymbol &&
            other.toAddress == toAddress &&
            other.amount == amount &&
            other.transactionType == transactionType &&
            other.amountInBaseUnits == amountInBaseUnits &&
            other.tokenDecimals == tokenDecimals &&
            other.memo == memo &&
            other.tokenContractAddress == tokenContractAddress;
  }

  @override
  int get hashCode {
    return Object.hash(
      chainId,
      chainType,
      assetSymbol,
      toAddress,
      amount,
      transactionType,
      amountInBaseUnits,
      tokenDecimals,
      memo,
      tokenContractAddress,
    );
  }
}
