import 'app_error.dart';

final class SecurityError implements AppError {
  const SecurityError.checkFailed()
      : code = 'security_check_failed',
        safeMessageKey = 'errors.securityCheckFailed',
        debugMessage = 'Security check failed';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
