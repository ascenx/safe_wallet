import 'app_error.dart';

final class DappError implements AppError {
  const DappError.userRejected()
      : code = 'dapp_user_rejected',
        safeMessageKey = 'errors.dappRejected',
        debugMessage = 'User rejected dApp request';

  const DappError.unsupportedMethod(String method)
      : code = 'dapp_unsupported_method',
        safeMessageKey = 'errors.dappUnsupportedMethod',
        debugMessage = 'Unsupported dApp method: $method';

  const DappError.unauthorized()
      : code = 'dapp_unauthorized',
        safeMessageKey = 'errors.dappUnauthorized',
        debugMessage = 'dApp is not authorized';

  const DappError.requestFailed()
      : code = 'dapp_request_failed',
        safeMessageKey = 'errors.unknown',
        debugMessage = 'dApp request failed';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
