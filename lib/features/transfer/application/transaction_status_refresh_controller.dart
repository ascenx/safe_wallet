import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/selected_chain_controller.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../data/transaction_status_lookup_service.dart';
import '../domain/transaction_record.dart';
import 'transaction_history_provider.dart';

final transactionStatusLookupServiceProvider =
    Provider<TransactionStatusLookupService>((ref) {
      final service = DefaultTransactionStatusLookupService();
      ref.onDispose(() => unawaited(service.close()));
      return service;
    });

final transactionStatusRefreshControllerProvider =
    AsyncNotifierProvider<TransactionStatusRefreshController, void>(
      TransactionStatusRefreshController.new,
    );

final class TransactionStatusRefreshController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> refreshCurrentChain() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_refreshCurrentChain);
  }

  Future<void> _refreshCurrentChain() async {
    final chain = await ref.read(selectedChainControllerProvider.future);
    final rpcNode = await ref.read(
      selectedResolvedRpcNodeProvider(chain).future,
    );
    final repository = ref.read(transactionHistoryRepositoryProvider);
    final lookupService = ref.read(transactionStatusLookupServiceProvider);
    final records = await repository.list(chainId: chain.chainId);

    final refreshable = records.where(_canRefresh).toList(growable: false);
    var nextIndex = 0;
    Future<void> worker() async {
      while (nextIndex < refreshable.length) {
        final record = refreshable[nextIndex];
        nextIndex += 1;
        try {
          final update = await lookupService.lookup(
            chain: chain,
            rpcNode: rpcNode,
            record: record,
          );
          if (update == null) {
            continue;
          }
          await repository.updateStatus(
            id: record.id,
            status: update.status,
            failureReason: update.failureReason,
          );
        } catch (_) {
          // A transient failure for one transaction must not prevent the
          // remaining pending records from being refreshed.
        }
      }
    }

    final workerCount = refreshable.length < _maximumConcurrentLookups
        ? refreshable.length
        : _maximumConcurrentLookups;
    await Future.wait([
      for (var index = 0; index < workerCount; index += 1) worker(),
    ]);

    ref.invalidate(transactionHistoryProvider(chain.chainId));
    ref.invalidate(transactionHistoryProvider(null));
    ref.invalidate(recentTransactionsProvider);
  }

  bool _canRefresh(TransactionRecord record) {
    return switch (record.status) {
      TransactionStatus.submitting || TransactionStatus.submitted => true,
      TransactionStatus.success || TransactionStatus.failed => false,
    };
  }
}

const _maximumConcurrentLookups = 4;
