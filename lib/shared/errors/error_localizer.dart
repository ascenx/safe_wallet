import '../../i18n/generated/translations.g.dart';
import 'app_error.dart';

final class ErrorLocalizer {
  const ErrorLocalizer();

  String messageFor(AppError error, Translations translations) {
    return switch (error.safeMessageKey) {
      'errors.walletLocked' => translations.errors.walletLocked,
      'errors.invalidMnemonic' => translations.errors.invalidMnemonic,
      'errors.invalidPrivateKey' => translations.errors.invalidPrivateKey,
      'errors.passwordAttemptLocked' =>
        translations.errors.passwordAttemptLocked,
      'errors.walletPasswordTooShort' =>
        translations.errors.walletPasswordTooShort,
      'errors.walletPasswordTooWeak' =>
        translations.errors.walletPasswordTooWeak,
      'errors.invalidRpcUrl' => translations.errors.invalidRpcUrl,
      'errors.rpcUnavailable' => translations.errors.rpcUnavailable,
      'errors.rpcMissingCredential' => translations.errors.rpcMissingCredential,
      'errors.rpcInvalidCredential' => translations.errors.rpcInvalidCredential,
      'errors.rpcAccessDenied' => translations.errors.rpcAccessDenied,
      'errors.rpcRateLimited' => translations.errors.rpcRateLimited,
      'errors.rpcChainMismatch' => translations.errors.rpcChainMismatch,
      'errors.balanceQueryFailed' => translations.errors.balanceQueryFailed,
      'errors.feeEstimateFailed' => translations.errors.feeEstimateFailed,
      'errors.transactionBroadcastFailed' =>
        translations.errors.transactionBroadcastFailed,
      'errors.suiInsufficientBalance' =>
        translations.errors.suiInsufficientBalance,
      'errors.suiInsufficientGas' => translations.errors.suiInsufficientGas,
      'errors.suiObjectConflict' => translations.errors.suiObjectConflict,
      'errors.suiSimulationFailed' => translations.errors.suiSimulationFailed,
      'errors.dappRejected' => translations.errors.dappRejected,
      'errors.dappUnsupportedMethod' =>
        translations.errors.dappUnsupportedMethod,
      'errors.dappUnauthorized' => translations.errors.dappUnauthorized,
      'errors.unsupportedChain' => translations.errors.unsupportedChain,
      'errors.securityCheckFailed' => translations.errors.securityCheckFailed,
      _ => translations.errors.unknown,
    };
  }
}
