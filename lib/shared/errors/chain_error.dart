import 'app_error.dart';

final class ChainError implements AppError {
  const ChainError.unsupportedChain()
      : code = 'unsupported_chain',
        safeMessageKey = 'errors.unsupportedChain',
        debugMessage = 'Requested chain is not supported';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
