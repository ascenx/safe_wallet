enum WalletPasswordIssue { tooShort, tooCommon }

final class WalletPasswordPolicy {
  const WalletPasswordPolicy._();

  static const minLength = 8;

  static const _commonPasswords = <String>{
    '123456',
    '12345678',
    '123456789012',
    'admin1234567',
    'changeme1234',
    'iloveyou1234',
    'letmein12345',
    'password1234',
    'qwerty123456',
  };
  static final _commonPasswordPattern = RegExp(
    r'^(password|qwerty|admin|letmein|iloveyou|changeme)'
    r'[0-9!@#\$%^&*._-]*$',
  );

  static WalletPasswordIssue? issueFor(String password) {
    final normalized = password.trim().toLowerCase();
    if (normalized.runes.length < minLength) {
      return WalletPasswordIssue.tooShort;
    }
    if (_commonPasswords.contains(normalized) ||
        _commonPasswordPattern.hasMatch(normalized) ||
        RegExp(r'^(.)\1{7,}$').hasMatch(normalized)) {
      return WalletPasswordIssue.tooCommon;
    }
    return null;
  }
}
