import '../domain/transaction_record.dart';

abstract interface class TransactionHistoryRepository {
  Future<void> save(TransactionRecord record);

  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  });

  Future<List<TransactionRecord>> list({String? chainId});

  Future<List<TransactionRecord>> recent({int limit = 4, String? chainId});
}

abstract interface class WalletScopedTransactionHistoryRepository {
  Future<List<TransactionRecord>> listForWallet({
    required String walletId,
    String? chainId,
  });

  Future<List<TransactionRecord>> recentForWallet({
    required String walletId,
    int limit = 4,
    String? chainId,
  });

  Future<void> deleteForWallet(String walletId);
}
