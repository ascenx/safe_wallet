import 'app_error.dart';

final class TransferError implements AppError {
  const TransferError.feeEstimateFailed()
    : code = 'fee_estimate_failed',
      safeMessageKey = 'errors.feeEstimateFailed',
      debugMessage = 'Transaction fee estimate failed';

  const TransferError.broadcastFailed()
    : code = 'transaction_broadcast_failed',
      safeMessageKey = 'errors.transactionBroadcastFailed',
      debugMessage = 'Transaction broadcast failed';

  const TransferError.insufficientBalance()
    : code = 'insufficient_balance',
      safeMessageKey = 'transfer.insufficientBalance',
      debugMessage = 'Balance cannot cover the transfer amount and fee';

  const TransferError.suiInsufficientBalance()
    : code = 'sui_insufficient_balance',
      safeMessageKey = 'errors.suiInsufficientBalance',
      debugMessage = 'Sui Coin balance is insufficient';

  const TransferError.suiInsufficientGas()
    : code = 'sui_insufficient_gas',
      safeMessageKey = 'errors.suiInsufficientGas',
      debugMessage = 'SUI gas balance is insufficient';

  const TransferError.suiObjectConflict()
    : code = 'sui_object_conflict',
      safeMessageKey = 'errors.suiObjectConflict',
      debugMessage = 'Sui object is unavailable or stale';

  const TransferError.suiSimulationFailed()
    : code = 'sui_simulation_failed',
      safeMessageKey = 'errors.suiSimulationFailed',
      debugMessage = 'Sui transaction simulation failed';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
