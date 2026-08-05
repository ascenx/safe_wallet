import '../../dapp/application/dapp_request_controller.dart';
import '../domain/wallet_connect_models.dart';

enum WalletConnectRequestValidation {
  valid,
  expired,
  invalidSession,
  unsupportedNamespace,
  unsupportedChain,
  unsupportedMethod,
  unauthorizedAccount,
  unsafeOrigin,
}

DappRpcRequest walletConnectDappRequest(
  WalletConnectRequest request, {
  String? authorizedAddress,
}) {
  final params = request.params;
  final verifyContext = request.verifyContext;
  return DappRpcRequest(
    id: request.id,
    origin:
        verifyContext?.status == WalletConnectVerifyStatus.valid &&
            verifyContext!.origin.isNotEmpty
        ? verifyContext.origin
        : request.peer.url,
    method: request.method,
    params: params is List
        ? List<Object?>.from(params)
        : params == null
        ? const []
        : [params],
    source: DappRequestSource.walletConnect,
    chainId: request.chain.toString(),
    requestTopic: request.topic,
    authorizedAddress: authorizedAddress,
    expiry: request.expiry,
  );
}

WalletConnectRequestValidation validateWalletConnectRequest({
  required WalletConnectRequest request,
  required WalletConnectSession session,
  required String accountAddress,
  required DateTime now,
}) {
  if (request.isExpiredAt(now)) {
    return WalletConnectRequestValidation.expired;
  }
  if (request.verifyContext?.blocksApproval == true) {
    return WalletConnectRequestValidation.unsafeOrigin;
  }
  if (session.topic != request.topic || session.isExpiredAt(now)) {
    return WalletConnectRequestValidation.invalidSession;
  }
  final namespace = session.namespaces[request.chain.namespace];
  if (namespace == null) {
    return WalletConnectRequestValidation.unsupportedNamespace;
  }
  if (!namespace.chains.contains(request.chain)) {
    return WalletConnectRequestValidation.unsupportedChain;
  }
  if (!namespace.methods.contains(request.method)) {
    return WalletConnectRequestValidation.unsupportedMethod;
  }
  if (!namespace.accounts.any(
    (account) => account.matches(chain: request.chain, address: accountAddress),
  )) {
    return WalletConnectRequestValidation.unauthorizedAccount;
  }
  return WalletConnectRequestValidation.valid;
}

WalletConnectResponse walletConnectResponse(
  WalletConnectRequest request,
  DappRequestResult result,
) {
  if (result.status == DappRequestResultStatus.success) {
    return WalletConnectResponse.success(id: request.id, result: result.value);
  }
  final rpcError = result.jsonRpcError;
  if (rpcError != null) {
    return WalletConnectResponse.error(
      id: request.id,
      error: WalletConnectResponseError(
        code: rpcError.code,
        message: rpcError.message,
      ),
    );
  }
  final error = switch (result.status) {
    DappRequestResultStatus.rejected ||
    DappRequestResultStatus.walletLocked => const WalletConnectResponseError(
      code: 5000,
      message: 'User rejected the request',
    ),
    DappRequestResultStatus.unsupported => const WalletConnectResponseError(
      code: 5100,
      message: 'Requested method is not supported',
    ),
    DappRequestResultStatus.authorizationRequired ||
    DappRequestResultStatus.confirmationRequired ||
    DappRequestResultStatus.failure => const WalletConnectResponseError(
      code: -32000,
      message: 'Request failed',
    ),
    DappRequestResultStatus.success => throw StateError('unreachable'),
  };
  return WalletConnectResponse.error(id: request.id, error: error);
}

WalletConnectResponse walletConnectValidationError(
  WalletConnectRequest request,
  WalletConnectRequestValidation validation,
) {
  final error = switch (validation) {
    WalletConnectRequestValidation.expired => const WalletConnectResponseError(
      code: 8000,
      message: 'Request expired',
    ),
    WalletConnectRequestValidation.invalidSession =>
      const WalletConnectResponseError(code: 7001, message: 'Invalid session'),
    WalletConnectRequestValidation.unsupportedNamespace ||
    WalletConnectRequestValidation.unsupportedChain ||
    WalletConnectRequestValidation.unsupportedMethod =>
      const WalletConnectResponseError(
        code: 5100,
        message: 'Requested capability is not supported',
      ),
    WalletConnectRequestValidation.unauthorizedAccount =>
      const WalletConnectResponseError(
        code: 4100,
        message: 'Account is not authorized',
      ),
    WalletConnectRequestValidation.unsafeOrigin =>
      const WalletConnectResponseError(
        code: 5100,
        message: 'Request origin failed security verification',
      ),
    WalletConnectRequestValidation.valid => throw StateError('unreachable'),
  };
  return WalletConnectResponse.error(id: request.id, error: error);
}
