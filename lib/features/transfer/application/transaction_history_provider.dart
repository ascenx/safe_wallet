import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/selected_chain_controller.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../data/transaction_history_repository.dart';
import '../domain/transaction_record.dart';

final transactionHistoryRepositoryProvider =
    Provider<TransactionHistoryRepository>((ref) {
      throw UnimplementedError(
        'transactionHistoryRepositoryProvider must be overridden',
      );
    });

final transactionHistoryProvider =
    FutureProvider.family<List<TransactionRecord>, String?>((ref, chainId) {
      final repository = ref.watch(transactionHistoryRepositoryProvider);
      final walletId = ref.watch(selectedWalletIdProvider);
      final scopedRepository =
          repository is WalletScopedTransactionHistoryRepository
          ? repository as WalletScopedTransactionHistoryRepository
          : null;
      if (walletId != null && scopedRepository != null) {
        return scopedRepository.listForWallet(
          walletId: walletId,
          chainId: chainId,
        );
      }
      return repository.list(chainId: chainId);
    });

final recentTransactionsProvider = FutureProvider<List<TransactionRecord>>((
  ref,
) async {
  final chain = await ref.watch(selectedChainControllerProvider.future);
  final repository = ref.watch(transactionHistoryRepositoryProvider);
  final walletId = ref.watch(selectedWalletIdProvider);
  final scopedRepository =
      repository is WalletScopedTransactionHistoryRepository
      ? repository as WalletScopedTransactionHistoryRepository
      : null;
  if (walletId != null && scopedRepository != null) {
    return scopedRepository.recentForWallet(
      walletId: walletId,
      limit: 4,
      chainId: chain.chainId,
    );
  }
  return repository.recent(limit: 4, chainId: chain.chainId);
});
