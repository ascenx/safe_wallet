import 'app_error.dart';

final class AssetError implements AppError {
  const AssetError.balanceQueryFailed()
      : code = 'balance_query_failed',
        safeMessageKey = 'errors.balanceQueryFailed',
        debugMessage = 'Asset balance query failed';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
