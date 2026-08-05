import 'app_error.dart';

final class WalletError implements AppError {
  const WalletError.walletLocked()
    : code = 'wallet_locked',
      safeMessageKey = 'errors.walletLocked',
      debugMessage = 'Wallet is locked';

  const WalletError.invalidMnemonic()
    : code = 'invalid_mnemonic',
      safeMessageKey = 'errors.invalidMnemonic',
      debugMessage = 'Mnemonic format or checksum is invalid';

  const WalletError.invalidPrivateKey()
    : code = 'invalid_private_key',
      safeMessageKey = 'errors.invalidPrivateKey',
      debugMessage = 'Private key format is invalid';

  const WalletError.passwordAttemptLocked()
    : code = 'password_attempt_locked',
      safeMessageKey = 'errors.passwordAttemptLocked',
      debugMessage = 'Too many password attempts';

  const WalletError.passwordTooShort()
    : code = 'wallet_password_too_short',
      safeMessageKey = 'errors.walletPasswordTooShort',
      debugMessage = 'Wallet password is shorter than 8 characters';

  const WalletError.weakPassword()
    : code = 'weak_wallet_password',
      safeMessageKey = 'errors.walletPasswordTooWeak',
      debugMessage = 'Wallet password is too common';

  const WalletError.dataIntegrityFailed()
    : code = 'wallet_data_integrity_failed',
      safeMessageKey = 'errors.securityCheckFailed',
      debugMessage =
          'Wallet key material does not match stored account metadata';

  @override
  final String code;

  @override
  final String safeMessageKey;

  @override
  final String debugMessage;
}
