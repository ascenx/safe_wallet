import '../errors/wallet_error.dart';

final class PasswordAttemptSnapshot {
  const PasswordAttemptSnapshot({
    required this.failedAttempts,
    required this.lockoutLevel,
    required this.lockedUntil,
  });

  final int failedAttempts;
  final int lockoutLevel;
  final DateTime? lockedUntil;
}

abstract interface class PasswordAttemptStore {
  PasswordAttemptSnapshot? read(String walletId);

  Future<void> write(String walletId, PasswordAttemptSnapshot snapshot);

  Future<void> remove(String walletId);
}

final class InMemoryPasswordAttemptStore implements PasswordAttemptStore {
  final Map<String, PasswordAttemptSnapshot> _states = {};

  @override
  PasswordAttemptSnapshot? read(String walletId) => _states[walletId];

  @override
  Future<void> write(String walletId, PasswordAttemptSnapshot snapshot) async {
    _states[walletId] = snapshot;
  }

  @override
  Future<void> remove(String walletId) async {
    _states.remove(walletId);
  }
}

final class PasswordAttemptLimiter {
  PasswordAttemptLimiter({this.maxAttempts = 5, PasswordAttemptStore? store})
    : _store = store ?? InMemoryPasswordAttemptStore();

  static const _lockoutDurations = [
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  final int maxAttempts;
  final PasswordAttemptStore _store;

  Future<void> assertAllowed({
    required String walletId,
    required DateTime now,
  }) async {
    final state = _store.read(walletId);
    final lockedUntil = state?.lockedUntil;
    if (state == null || lockedUntil == null) {
      return;
    }
    if (now.isBefore(lockedUntil)) {
      throw const WalletError.passwordAttemptLocked();
    }
    await _store.write(
      walletId,
      PasswordAttemptSnapshot(
        failedAttempts: state.failedAttempts,
        lockoutLevel: state.lockoutLevel,
        lockedUntil: null,
      ),
    );
  }

  Future<void> recordFailure({
    required String walletId,
    required DateTime now,
  }) async {
    final current = _store.read(walletId);
    final nextAttempts = (current?.failedAttempts ?? 0) + 1;
    final shouldLock = nextAttempts >= maxAttempts;
    final lockoutLevel = shouldLock
        ? (current?.lockoutLevel ?? 0) + 1
        : current?.lockoutLevel ?? 0;
    final durationIndex = (lockoutLevel - 1).clamp(
      0,
      _lockoutDurations.length - 1,
    );
    await _store.write(
      walletId,
      PasswordAttemptSnapshot(
        failedAttempts: nextAttempts,
        lockoutLevel: lockoutLevel,
        lockedUntil: shouldLock
            ? now.add(_lockoutDurations[durationIndex])
            : null,
      ),
    );
  }

  Future<void> recordSuccess(String walletId) {
    return _store.remove(walletId);
  }
}
