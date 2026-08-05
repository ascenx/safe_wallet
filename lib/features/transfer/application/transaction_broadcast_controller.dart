import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/transfer_error.dart';
import '../../../shared/errors/wallet_error.dart';
import '../../../shared/utils/bitcoin_address.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/bitcoin_transaction_service.dart';
import '../data/evm_transaction_service.dart';
import '../data/solana_transaction_service.dart';
import '../data/sui_transaction_service.dart';
import '../data/tron_transaction_service.dart';
import '../domain/transaction_record.dart';
import '../domain/transaction_request.dart';
import 'fee_estimate_provider.dart';
import 'transaction_history_provider.dart';

typedef TransactionBroadcastClock = DateTime Function();

final evmTransactionServiceProvider = Provider<EvmTransactionService>((ref) {
  return const Web3EvmTransactionService();
});

final bitcoinTransactionServiceProvider = Provider<BitcoinTransactionService>((
  ref,
) {
  final service = HttpBitcoinTransactionService();
  ref.onDispose(service.close);
  return service;
});

final solanaTransactionServiceProvider = Provider<SolanaTransactionService>((
  ref,
) {
  return const SdkSolanaTransactionService();
});

final tronTransactionServiceProvider = Provider<TronTransactionService>((ref) {
  final service = HttpTronTransactionService();
  ref.onDispose(service.close);
  return service;
});

final transactionBroadcastClockProvider = Provider<TransactionBroadcastClock>((
  ref,
) {
  return () => DateTime.now().toUtc();
});

final transactionBroadcastControllerProvider =
    NotifierProvider<TransactionBroadcastController, TransactionBroadcastState>(
      TransactionBroadcastController.new,
    );

enum TransactionBroadcastStatus { idle, submitting, success, failure }

final class TransactionBroadcastState {
  const TransactionBroadcastState._({
    required this.status,
    this.transactionHash,
    this.record,
    this.error,
  });

  const TransactionBroadcastState.idle()
    : this._(status: TransactionBroadcastStatus.idle);

  const TransactionBroadcastState.submitting()
    : this._(status: TransactionBroadcastStatus.submitting);

  const TransactionBroadcastState.success({
    required String transactionHash,
    required TransactionRecord record,
  }) : this._(
         status: TransactionBroadcastStatus.success,
         transactionHash: transactionHash,
         record: record,
       );

  const TransactionBroadcastState.failure(AppError error)
    : this._(status: TransactionBroadcastStatus.failure, error: error);

  final TransactionBroadcastStatus status;
  final String? transactionHash;
  final TransactionRecord? record;
  final AppError? error;
}

final class TransactionBroadcastRequest {
  const TransactionBroadcastRequest({
    required this.chain,
    required this.rpcNode,
    required this.account,
    required this.transaction,
    required this.feeEstimate,
  });

  final ChainConfig chain;
  final RpcNode rpcNode;
  final WalletAccount account;
  final TransactionRequest transaction;
  final FeeEstimate feeEstimate;
}

final class TransactionBroadcastController
    extends Notifier<TransactionBroadcastState> {
  Future<TransactionBroadcastState>? _submissionInFlight;

  @override
  TransactionBroadcastState build() {
    return const TransactionBroadcastState.idle();
  }

  Future<TransactionBroadcastState> submit(
    TransactionBroadcastRequest request, {
    String? signingPassword,
    bool rememberSigningPassword = true,
  }) {
    final submissionInFlight = _submissionInFlight;
    if (submissionInFlight != null) {
      return submissionInFlight;
    }
    final submission = _submit(
      request,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    _submissionInFlight = submission;
    return submission;
  }

  Future<TransactionBroadcastState> _submit(
    TransactionBroadcastRequest request, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    state = const TransactionBroadcastState.submitting();
    try {
      final keyMaterial = await _readSigningKeyMaterial(
        request.account.id,
        signingPassword: signingPassword,
        rememberSigningPassword: rememberSigningPassword,
      );
      final transactionHash = await _signAndBroadcast(request, keyMaterial);
      await ref
          .read(securityLogRecorderProvider)
          .record(
            SecurityLogEventType.signTransaction,
            walletName: request.account.name,
            chainName: request.chain.name,
            assetSymbol: request.transaction.assetSymbol,
            amount: request.transaction.amount,
          );
      final record = _recordFor(request, transactionHash);
      try {
        await ref.read(transactionHistoryRepositoryProvider).save(record);
        ref.invalidate(transactionHistoryProvider(request.chain.chainId));
        ref.invalidate(recentTransactionsProvider);
      } catch (_) {
        // The chain accepted the transaction. A local persistence failure must
        // never invite the user to broadcast the same payment again.
      }

      final success = TransactionBroadcastState.success(
        transactionHash: transactionHash,
        record: record,
      );
      state = success;
      return success;
    } on WalletError catch (error) {
      return _fail(error);
    } on TransferError catch (error) {
      return _fail(error);
    } catch (_) {
      return _fail(const TransferError.broadcastFailed());
    } finally {
      _submissionInFlight = null;
    }
  }

  Future<WalletKeyMaterial> _readSigningKeyMaterial(
    String walletId, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final now = ref.read(transactionBroadcastClockProvider)();
    final cache = ref.read(sessionKeyCacheProvider);
    final cachedWalletDek = cache.readKey(walletId, now: now);
    if (cachedWalletDek != null) {
      cache.touch(now: now);
      return ref
          .read(walletRepositoryProvider)
          .readKeyMaterial(walletId: walletId, walletDek: cachedWalletDek);
    }

    if (signingPassword == null || signingPassword.isEmpty) {
      throw const WalletError.walletLocked();
    }

    final unlockResult = await ref
        .read(walletRepositoryProvider)
        .unlock(walletId: walletId, password: signingPassword);
    final walletDek = unlockResult.walletDek;
    if (rememberSigningPassword) {
      cache.unlock(
        walletId: unlockResult.account.id,
        walletDek: walletDek,
        now: now,
      );
    }
    return ref
        .read(walletRepositoryProvider)
        .readKeyMaterial(walletId: walletId, walletDek: walletDek);
  }

  Future<String> _signAndBroadcast(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    return switch (request.chain.chainType) {
      ChainType.evm => _signAndBroadcastEvm(request, keyMaterial),
      ChainType.bitcoin => _signAndBroadcastBitcoin(request, keyMaterial),
      ChainType.tron => _signAndBroadcastTron(request, keyMaterial),
      ChainType.solana => _signAndBroadcastSolana(request, keyMaterial),
      ChainType.sui => _signAndBroadcastSui(request, keyMaterial),
    };
  }

  Future<String> _signAndBroadcastEvm(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    final privateKey = keyMaterial.evmPrivateKey;
    if (privateKey == null) {
      throw const TransferError.broadcastFailed();
    }
    return ref
        .read(evmTransactionServiceProvider)
        .signAndBroadcast(
          EvmTransactionBroadcastInput(
            rpcUrl: request.rpcNode.endpointUrl,
            chainId: int.parse(request.chain.chainId),
            privateKey: privateKey,
            fromAddress: request.account.evmAddress,
            transaction: request.transaction,
            feeEstimate: request.feeEstimate,
            headers: request.rpcNode.endpointHeaders,
          ),
        );
  }

  Future<String> _signAndBroadcastBitcoin(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    if (!_isBitcoinAddressForChain(request.account.btcAddress, request.chain) ||
        !_isBitcoinAddressForChain(
          request.transaction.toAddress,
          request.chain,
        )) {
      throw const TransferError.broadcastFailed();
    }
    final privateKey = keyMaterial.btcPrivateKey;
    if (privateKey == null) {
      throw const TransferError.broadcastFailed();
    }
    return ref
        .read(bitcoinTransactionServiceProvider)
        .signAndBroadcast(
          BitcoinTransactionBroadcastInput(
            apiBaseUrl: request.rpcNode.endpointUrl,
            privateKey: privateKey,
            fromAddress: request.account.btcAddress,
            transaction: request.transaction,
            feeEstimate: request.feeEstimate,
          ),
        );
  }

  Future<String> _signAndBroadcastSolana(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    final privateKey = keyMaterial.solanaPrivateKey;
    if (privateKey == null) {
      throw const TransferError.broadcastFailed();
    }
    return ref
        .read(solanaTransactionServiceProvider)
        .signAndBroadcast(
          SolanaTransactionBroadcastInput(
            rpcUrl: request.rpcNode.endpointUrl,
            privateKey: privateKey,
            fromAddress: request.account.solanaAddress,
            transaction: request.transaction,
            recentBlockhash: null,
            computeUnitLimit: request.feeEstimate.computeUnitLimit,
            microLamportsPerComputeUnit:
                request.feeEstimate.microLamportsPerComputeUnit,
            headers: request.rpcNode.endpointHeaders,
          ),
        );
  }

  Future<String> _signAndBroadcastTron(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    final privateKey = keyMaterial.tronPrivateKey;
    if (privateKey == null || request.account.tronAddress.isEmpty) {
      throw const TransferError.broadcastFailed();
    }
    return ref
        .read(tronTransactionServiceProvider)
        .signAndBroadcast(
          TronTransactionBroadcastInput(
            apiBaseUrl: request.rpcNode.endpointUrl,
            privateKey: privateKey,
            fromAddress: request.account.tronAddress,
            transaction: request.transaction,
            headers: request.rpcNode.endpointHeaders,
            feeLimitSun: request.feeEstimate.feeLimitSun,
          ),
        );
  }

  Future<String> _signAndBroadcastSui(
    TransactionBroadcastRequest request,
    WalletKeyMaterial keyMaterial,
  ) {
    final privateKey = keyMaterial.suiPrivateKey;
    if (privateKey == null || request.account.suiAddress.isEmpty) {
      throw const TransferError.broadcastFailed();
    }
    return ref
        .read(suiTransactionServiceProvider)
        .signAndBroadcast(
          SuiTransactionBroadcastInput(
            rpcUrl: request.rpcNode.endpointUrl,
            privateKey: privateKey,
            fromAddress: request.account.suiAddress,
            transaction: request.transaction,
            headers: request.rpcNode.endpointHeaders,
          ),
        );
  }

  TransactionRecord _recordFor(
    TransactionBroadcastRequest request,
    String transactionHash,
  ) {
    final now = ref.read(transactionBroadcastClockProvider)();
    return TransactionRecord(
      id: 'tx-${now.microsecondsSinceEpoch}',
      walletId: request.account.id,
      chainId: request.chain.chainId,
      chainType: request.chain.chainType,
      assetSymbol: request.transaction.assetSymbol,
      direction: TransactionDirection.outgoing,
      amount: request.transaction.amount,
      status: TransactionStatus.submitted,
      transactionHash: transactionHash,
      createdAt: now,
      fromAddress: _fromAddress(request),
      toAddress: request.transaction.toAddress,
      memo: request.transaction.memo,
    );
  }

  String _fromAddress(TransactionBroadcastRequest request) {
    return switch (request.chain.chainType) {
      ChainType.evm => request.account.evmAddress,
      ChainType.bitcoin => request.account.btcAddress,
      ChainType.tron => request.account.tronAddress,
      ChainType.solana => request.account.solanaAddress,
      ChainType.sui => request.account.suiAddress,
    };
  }

  TransactionBroadcastState _fail(AppError error) {
    final failure = TransactionBroadcastState.failure(error);
    state = failure;
    return failure;
  }
}

bool _isBitcoinAddressForChain(String address, ChainConfig chain) {
  return isBitcoinAddressForNetwork(address, isTestnet: chain.isTestnet);
}
