import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors/dapp_error.dart';
import '../../../shared/utils/sui_address.dart';
import '../../assets/application/token_repository_provider.dart';
import '../../assets/domain/token_info.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/domain/transaction_record.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/application/wallet_session_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../domain/dapp_permission.dart';
import '../domain/eip712_typed_data.dart';
import 'dapp_permission_controller.dart';
import '../data/dapp_chain_request_services.dart';
import '../data/dapp_transaction.dart';
import '../data/dapp_transaction_previewer.dart';
import 'dapp_request_models.dart';

export '../data/dapp_chain_request_services.dart';
export '../data/dapp_transaction.dart';
export '../data/dapp_transaction_previewer.dart';
export 'dapp_request_models.dart';

part 'dapp_evm_request_handler.dart';
part 'dapp_solana_request_handler.dart';
part 'dapp_sui_request_handler.dart';
part 'dapp_request_helpers.dart';

final dappRequestControllerProvider =
    NotifierProvider<DappRequestController, DappRequestState>(
      DappRequestController.new,
    );

final dappEvmTransactionSenderProvider = Provider<DappEvmTransactionSender>(
  (ref) => const Web3DappEvmTransactionSender(),
);

final dappEvmTransactionSignerProvider = Provider<DappEvmTransactionSigner>(
  (ref) => const Web3DappEvmTransactionSigner(),
);

final dappEvmMessageSignerProvider = Provider<DappEvmMessageSigner>(
  (ref) => const Web3DappEvmMessageSigner(),
);

final dappEvmReadRpcClientProvider = Provider<DappEvmReadRpcClient>((ref) {
  final client = HttpDappEvmReadRpcClient();
  ref.onDispose(client.close);
  return client;
});

final dappEvmTransactionSimulatorProvider =
    Provider<DappEvmTransactionSimulator>(
      (ref) => RpcDappEvmTransactionSimulator(
        rpcClient: ref.watch(dappEvmReadRpcClientProvider),
      ),
    );

typedef DappEvmTokenLookup =
    Future<TokenInfo?> Function({
      required String chainId,
      required String contractAddress,
    });

final dappEvmTokenLookupProvider = Provider<DappEvmTokenLookup>((ref) {
  return ({required chainId, required contractAddress}) async {
    try {
      final tokens = await ref
          .read(tokenRepositoryProvider)
          .getTokens(chainId: chainId, includeHidden: true);
      final normalizedContract = contractAddress.toLowerCase();
      for (final token in tokens) {
        if (token.contractAddress?.toLowerCase() == normalizedContract) {
          return token;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  };
});

final dappSolanaMessageSignerProvider = Provider<DappSolanaMessageSigner>(
  (ref) => const SdkDappSolanaMessageSigner(),
);

final dappSolanaTransactionSignerProvider =
    Provider<DappSolanaTransactionSigner>(
      (ref) => const SdkDappSolanaTransactionSigner(),
    );

final dappSolanaRawTransactionSenderProvider =
    Provider<DappSolanaRawTransactionSender>((ref) {
      final sender = HttpDappSolanaRawTransactionSender();
      ref.onDispose(sender.close);
      return sender;
    });

final dappSuiSignerProvider = Provider<DappSuiSigner>(
  (ref) => const SdkDappSuiSigner(),
);

final dappSuiTransactionExecutorProvider = Provider<DappSuiTransactionExecutor>(
  (ref) => const GrpcDappSuiTransactionExecutor(),
);

final dappTransactionPreviewerProvider = Provider<DappTransactionPreviewer>(
  (ref) => const SdkDappTransactionPreviewer(),
);

final class DappRequestController extends Notifier<DappRequestState> {
  @override
  DappRequestState build() {
    ref.listen(selectedChainControllerProvider, (_, _) {
      state = const DappRequestState.idle();
    });
    ref.listen(walletSessionControllerProvider, (_, _) {
      state = const DappRequestState.idle();
    });
    return const DappRequestState.idle();
  }

  Ref get _requestRef => ref;

  Future<DappRequestResult> handle(
    DappRpcRequest request, {
    DappAuthorizationDecision? authorizationDecision,
    DappConfirmationDecision? confirmationDecision,
    String? signingPassword,
    bool rememberSigningPassword = true,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now().toUtc();
    try {
      return switch (request.method) {
        'eth_requestAccounts' => _requestAccounts(
          request,
          authorizationDecision: authorizationDecision,
          now: timestamp,
        ),
        'wallet_requestPermissions' => _requestPermissions(
          request,
          authorizationDecision: authorizationDecision,
          now: timestamp,
        ),
        'wallet_getPermissions' => _getPermissions(request, now: timestamp),
        'eth_accounts' => _accounts(request, now: timestamp),
        'eth_chainId' => _chainId(request),
        'net_version' => _netVersion(request),
        'personal_sign' => _personalSign(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'eth_signTypedData_v4' => _signTypedDataV4(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'eth_sendTransaction' => _sendTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'eth_signTransaction' => _sendTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          signOnly: true,
          now: timestamp,
        ),
        'wallet_switchEthereumChain' => _switchEthereumChain(
          request,
          confirmationDecision: confirmationDecision,
        ),
        'solana_connect' => _connectSolana(
          request,
          authorizationDecision: authorizationDecision,
          now: timestamp,
        ),
        'solana_disconnect' => Future.value(
          const DappRequestResult.success(null),
        ),
        'solana_signMessage' => _signSolanaMessage(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'solana_signTransaction' => _signSolanaTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'solana_signAllTransactions' => _signAllSolanaTransactions(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'solana_signAndSendTransaction' => _signAndSendSolanaTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'sui_connect' => _connectSui(
          request,
          authorizationDecision: authorizationDecision,
          now: timestamp,
        ),
        'sui_disconnect' => _disconnectSui(request, now: timestamp),
        'sui_signPersonalMessage' => _signSuiPersonalMessage(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          now: timestamp,
        ),
        'sui_signTransaction' => _signSuiTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          execute: false,
          now: timestamp,
        ),
        'sui_signAndExecuteTransaction' => _signSuiTransaction(
          request,
          authorizationDecision: authorizationDecision,
          confirmationDecision: confirmationDecision,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
          execute: true,
          now: timestamp,
        ),
        _ when _isReadOnlyEvmRpcMethod(request.method) => _readEvmRpc(request),
        _ => Future.value(DappRequestResult.unsupported(request.method)),
      };
    } on DappError catch (error) {
      return DappRequestResult.failure(error.code);
    } catch (_) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
  }

  WalletAccount? _accountForRequest({
    required DappRpcRequest request,
    required List<WalletAccount> wallets,
    required bool Function(WalletAccount wallet, String address)
    matchesAuthorizedAddress,
  }) {
    final authorizedAddress = request.authorizedAddress?.trim();
    if (authorizedAddress != null && authorizedAddress.isNotEmpty) {
      return _firstWhereOrNull(
        wallets,
        (wallet) => matchesAuthorizedAddress(wallet, authorizedAddress),
      );
    }
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    return selectedWalletId == null
        ? _firstOrNull(wallets)
        : _firstWhereOrNull(wallets, (wallet) => wallet.id == selectedWalletId);
  }

  Future<void> _recordSignature(
    SecurityLogEventType type, {
    required WalletAccount account,
    required ChainConfig chain,
  }) {
    return ref
        .read(securityLogRecorderProvider)
        .record(type, walletName: account.name, chainName: chain.name);
  }

  Future<void> _recordBroadcastTransaction({
    required String idPrefix,
    required ChainConfig chain,
    required WalletAccount account,
    required String transactionHash,
    required String amount,
    required String memo,
    required DateTime now,
    String? toAddress,
  }) async {
    final record = TransactionRecord(
      id: '$idPrefix-${now.microsecondsSinceEpoch}',
      walletId: account.id,
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      direction: TransactionDirection.outgoing,
      amount: amount,
      status: TransactionStatus.submitted,
      transactionHash: transactionHash,
      createdAt: now,
      fromAddress: account.addressForChainType(chain.chainType),
      toAddress: toAddress,
      memo: memo,
    );
    try {
      await ref.read(transactionHistoryRepositoryProvider).save(record);
      ref.invalidate(transactionHistoryProvider(chain.chainId));
      ref.invalidate(recentTransactionsProvider);
    } catch (_) {
      // Broadcasting already succeeded. Keep the dApp response successful so
      // the caller cannot accidentally submit the transaction twice.
    }
  }

  Future<WalletKeyMaterial?> _readSigningKeyMaterial(
    String walletId,
    DateTime now, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final cache = ref.read(sessionKeyCacheProvider);
    final cachedWalletDek = cache.readKey(walletId, now: now);
    if (cachedWalletDek != null) {
      cache.touch(now: now);
      return ref
          .read(walletRepositoryProvider)
          .readKeyMaterial(walletId: walletId, walletDek: cachedWalletDek);
    }

    if (signingPassword == null || signingPassword.isEmpty) {
      return null;
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
}
