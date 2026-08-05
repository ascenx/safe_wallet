import '../../chains/domain/chain_config.dart';
import '../data/dapp_permission_repository.dart';
import '../data/dapp_transaction.dart';

enum DappAuthorizationDecision { approved, approvedForSession, rejected }

enum DappConfirmationDecision { approved, rejected }

enum DappRequestResultStatus {
  success,
  rejected,
  unsupported,
  walletLocked,
  authorizationRequired,
  confirmationRequired,
  failure,
}

enum DappConfirmationKind { authorization, signature, transaction, chainSwitch }

final class DappJsonRpcError {
  const DappJsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  final int code;
  final String message;
  final Object? data;
}

final class DappEvmReadRpcResponse {
  const DappEvmReadRpcResponse.result(this.result) : error = null;

  const DappEvmReadRpcResponse.error(this.error) : result = null;

  final Object? result;
  final DappJsonRpcError? error;
}

final class DappRequestState {
  const DappRequestState.idle();
}

enum DappRequestSource { internalBrowser, walletConnect }

final class DappRpcRequest {
  const DappRpcRequest({
    this.id,
    required this.origin,
    required this.method,
    this.params = const [],
    this.source = DappRequestSource.internalBrowser,
    this.chainId,
    this.requestTopic,
    this.authorizedAddress,
    this.expiry,
  });

  final Object? id;
  final String origin;
  final String method;
  final List<Object?> params;
  final DappRequestSource source;
  final String? chainId;
  final String? requestTopic;
  final String? authorizedAddress;
  final DateTime? expiry;

  String get domain => normalizeDappDomain(origin);

  DappRpcRequest copyWithExecutionContext({
    required String chainId,
    required String authorizedAddress,
  }) {
    return DappRpcRequest(
      id: id,
      origin: origin,
      method: method,
      params: params,
      source: source,
      chainId: chainId,
      requestTopic: requestTopic,
      authorizedAddress: authorizedAddress,
      expiry: expiry,
    );
  }
}

final class DappRequestResult {
  const DappRequestResult._({
    required this.status,
    this.value,
    this.errorCode,
    this.jsonRpcError,
    this.confirmation,
  });

  const DappRequestResult.success(Object? value)
    : this._(status: DappRequestResultStatus.success, value: value);

  const DappRequestResult.rejected()
    : this._(
        status: DappRequestResultStatus.rejected,
        errorCode: 'dapp_user_rejected',
      );

  const DappRequestResult.unsupported(String method)
    : this._(
        status: DappRequestResultStatus.unsupported,
        errorCode: 'dapp_unsupported_method',
      );

  const DappRequestResult.walletLocked()
    : this._(
        status: DappRequestResultStatus.walletLocked,
        errorCode: 'wallet_locked',
      );

  const DappRequestResult.authorizationRequired(
    DappRequestConfirmation confirmation,
  ) : this._(
        status: DappRequestResultStatus.authorizationRequired,
        confirmation: confirmation,
      );

  const DappRequestResult.confirmationRequired(
    DappRequestConfirmation confirmation,
  ) : this._(
        status: DappRequestResultStatus.confirmationRequired,
        confirmation: confirmation,
      );

  const DappRequestResult.failure(String errorCode)
    : this._(status: DappRequestResultStatus.failure, errorCode: errorCode);

  const DappRequestResult.jsonRpcError(DappJsonRpcError error)
    : this._(status: DappRequestResultStatus.failure, jsonRpcError: error);

  final DappRequestResultStatus status;
  final Object? value;
  final String? errorCode;
  final DappJsonRpcError? jsonRpcError;
  final DappRequestConfirmation? confirmation;

  bool get isSuccess => status == DappRequestResultStatus.success;
}

final class DappRequestConfirmation {
  const DappRequestConfirmation({
    required this.kind,
    required this.domain,
    required this.chain,
    required this.address,
    this.message,
    this.rawMessage,
    this.transaction,
    this.transactions = const [],
    this.requestedChain,
  });

  final DappConfirmationKind kind;
  final String domain;
  final ChainConfig chain;
  final String address;
  final String? message;
  final String? rawMessage;
  final DappTransactionPreview? transaction;
  final List<DappTransactionPreview> transactions;
  final ChainConfig? requestedChain;

  List<DappTransactionPreview> get transactionPreviews =>
      transactions.isNotEmpty ? transactions : [?transaction];
}

abstract interface class DappEvmTransactionSimulator {
  Future<DappTransactionSimulation> simulate({
    required ChainConfig chain,
    required String rpcUrl,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  });
}

abstract interface class DappEvmTransactionSender {
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  });
}

abstract interface class DappEvmTransactionSigner {
  Future<String> sign({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  });
}

abstract interface class DappEvmMessageSigner {
  Future<String> signPersonalMessage({
    required String privateKey,
    required List<int> message,
  });

  Future<String> signTypedData({
    required String privateKey,
    required List<int> payload,
  });
}

abstract interface class DappEvmReadRpcClient {
  Future<DappEvmReadRpcResponse> request({
    required ChainConfig chain,
    required String rpcUrl,
    required String method,
    required List<Object?> params,
    Map<String, String> headers = const {},
  });
}

abstract interface class DappSolanaMessageSigner {
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> message,
  });
}

abstract interface class DappSolanaTransactionSigner {
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> serializedTransaction,
  });
}

abstract interface class DappSolanaRawTransactionSender {
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> serializedTransaction,
    Map<String, String> headers = const {},
  });
}

abstract interface class DappTransactionPreviewer {
  DappTransactionPreview previewSolana({
    required String from,
    required List<int> serializedTransaction,
    int count = 1,
  });

  DappTransactionPreview? previewSui({
    required List<int> transactionBytes,
    required String expectedSender,
  });
}

final class DappSuiSignedData {
  const DappSuiSignedData({required this.bytes, required this.signature});

  final String bytes;
  final String signature;
}

abstract interface class DappSuiSigner {
  Future<DappSuiSignedData> signPersonalMessage({
    required List<int> privateKey,
    required List<int> message,
  });

  Future<DappSuiSignedData> signTransaction({
    required List<int> privateKey,
    required List<int> transactionBytes,
  });
}

abstract interface class DappSuiTransactionExecutor {
  Future<String> execute({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> transactionBytes,
    required String signature,
    Map<String, String> headers = const {},
  });
}
