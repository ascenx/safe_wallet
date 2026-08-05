import 'package:hive_ce/hive.dart';

import 'password_attempt_limiter.dart';

final class HivePasswordAttemptStore implements PasswordAttemptStore {
  HivePasswordAttemptStore({required Box<dynamic> settingsBox})
    : _settingsBox = settingsBox;

  static const _keyPrefix = 'passwordAttempt:';

  final Box<dynamic> _settingsBox;

  @override
  PasswordAttemptSnapshot? read(String walletId) {
    final value = _settingsBox.get('$_keyPrefix$walletId');
    if (value is! Map) {
      return null;
    }
    final failedAttempts = value['failedAttempts'];
    final lockoutLevel = value['lockoutLevel'];
    final lockedUntil = value['lockedUntil'];
    if (failedAttempts is! int || lockoutLevel is! int) {
      return null;
    }
    return PasswordAttemptSnapshot(
      failedAttempts: failedAttempts,
      lockoutLevel: lockoutLevel,
      lockedUntil: lockedUntil is String
          ? DateTime.tryParse(lockedUntil)
          : null,
    );
  }

  @override
  Future<void> write(String walletId, PasswordAttemptSnapshot snapshot) {
    return _settingsBox.put('$_keyPrefix$walletId', {
      'failedAttempts': snapshot.failedAttempts,
      'lockoutLevel': snapshot.lockoutLevel,
      if (snapshot.lockedUntil != null)
        'lockedUntil': snapshot.lockedUntil!.toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> remove(String walletId) =>
      _settingsBox.delete('$_keyPrefix$walletId');
}
