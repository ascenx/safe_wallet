import 'app_error.dart';

final class RpcError implements AppError {
  const RpcError.invalidUrl()
      : code = 'invalid_rpc_url',
        safeMessageKey = 'errors.invalidRpcUrl',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = 'RPC URL is invalid';

  const RpcError.unavailable({String? debugMessage})
      : code = 'rpc_unavailable',
        safeMessageKey = 'errors.rpcUnavailable',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = debugMessage ?? 'RPC node is unavailable';

  const RpcError.missingCredential()
      : code = 'rpc_missing_credential',
        safeMessageKey = 'errors.rpcMissingCredential',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = 'RPC credential is missing';

  const RpcError.invalidCredential()
      : code = 'rpc_invalid_credential',
        safeMessageKey = 'errors.rpcInvalidCredential',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = 'RPC credential is invalid';

  const RpcError.accessDenied()
      : code = 'rpc_access_denied',
        safeMessageKey = 'errors.rpcAccessDenied',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = 'RPC access is denied';

  const RpcError.rateLimited()
      : code = 'rpc_rate_limited',
        safeMessageKey = 'errors.rpcRateLimited',
        expectedChainId = null,
        actualChainId = null,
        _debugMessage = 'RPC request is rate limited';

  const RpcError.chainMismatch({
    required this.expectedChainId,
    required this.actualChainId,
  })  : code = 'rpc_chain_mismatch',
        safeMessageKey = 'errors.rpcChainMismatch',
        _debugMessage = null;

  final String? expectedChainId;
  final String? actualChainId;
  final String? _debugMessage;

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  String get debugMessage {
    final debugMessage = _debugMessage;
    if (debugMessage != null) {
      return debugMessage;
    }
    return 'RPC chain mismatch: expected=$expectedChainId actual=$actualChainId';
  }
}
