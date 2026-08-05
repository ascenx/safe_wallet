import '../../chains/domain/chain_config.dart';

enum TransactionDirection { incoming, outgoing }

enum TransactionStatus { submitting, submitted, success, failed }

enum TransactionOperation {
  transfer,
  wrap,
  unwrap,
  stake,
  unstake,
  withdrawUnfreeze,
  cancelUnfreeze,
  delegateResource,
  undelegateResource,
  vote,
  claimReward,
}

final class TransactionRecord {
  const TransactionRecord({
    required this.id,
    this.walletId,
    required this.chainId,
    required this.chainType,
    required this.assetSymbol,
    required this.direction,
    required this.amount,
    required this.status,
    required this.transactionHash,
    required this.createdAt,
    this.fromAddress,
    this.toAddress,
    this.memo,
    this.failureReason,
    this.operation = TransactionOperation.transfer,
    this.resource,
  });

  final String id;
  final String? walletId;
  final String chainId;
  final ChainType chainType;
  final String assetSymbol;
  final TransactionDirection direction;
  final String amount;
  final TransactionStatus status;
  final String transactionHash;
  final DateTime createdAt;
  final String? fromAddress;
  final String? toAddress;
  final String? memo;
  final String? failureReason;
  final TransactionOperation operation;
  final String? resource;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionRecord &&
            other.id == id &&
            other.walletId == walletId &&
            other.chainId == chainId &&
            other.chainType == chainType &&
            other.assetSymbol == assetSymbol &&
            other.direction == direction &&
            other.amount == amount &&
            other.status == status &&
            other.transactionHash == transactionHash &&
            other.createdAt == createdAt &&
            other.fromAddress == fromAddress &&
            other.toAddress == toAddress &&
            other.memo == memo &&
            other.failureReason == failureReason &&
            other.operation == operation &&
            other.resource == resource;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      walletId,
      chainId,
      chainType,
      assetSymbol,
      direction,
      amount,
      status,
      transactionHash,
      createdAt,
      fromAddress,
      toAddress,
      memo,
      failureReason,
      operation,
      resource,
    );
  }
}
