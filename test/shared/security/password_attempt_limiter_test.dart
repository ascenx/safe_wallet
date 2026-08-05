import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/security/password_attempt_limiter.dart';

void main() {
  test('lockout survives a new limiter instance', () async {
    final store = _MemoryPasswordAttemptStore();
    final now = DateTime.utc(2026, 8, 2, 12);
    final limiter = PasswordAttemptLimiter(store: store);
    for (var attempt = 0; attempt < 5; attempt += 1) {
      await limiter.recordFailure(walletId: 'wallet-1', now: now);
    }

    final restartedLimiter = PasswordAttemptLimiter(store: store);

    expect(
      () async => restartedLimiter.assertAllowed(
        walletId: 'wallet-1',
        now: now.add(const Duration(seconds: 10)),
      ),
      throwsA(isA<WalletError>()),
    );
  });

  test(
    'repeated lockouts increase from 30 seconds to 2 and 10 minutes',
    () async {
      final store = _MemoryPasswordAttemptStore();
      final limiter = PasswordAttemptLimiter(store: store);
      final start = DateTime.utc(2026, 8, 2, 12);
      for (var attempt = 0; attempt < 5; attempt += 1) {
        await limiter.recordFailure(walletId: 'wallet-1', now: start);
      }
      expect(
        store.states['wallet-1']?.lockedUntil,
        start.add(const Duration(seconds: 30)),
      );

      final afterFirstLock = start.add(const Duration(seconds: 31));
      await limiter.assertAllowed(walletId: 'wallet-1', now: afterFirstLock);
      await limiter.recordFailure(walletId: 'wallet-1', now: afterFirstLock);
      expect(
        store.states['wallet-1']?.lockedUntil,
        afterFirstLock.add(const Duration(minutes: 2)),
      );

      final afterSecondLock = afterFirstLock.add(const Duration(minutes: 3));
      await limiter.assertAllowed(walletId: 'wallet-1', now: afterSecondLock);
      await limiter.recordFailure(walletId: 'wallet-1', now: afterSecondLock);
      expect(
        store.states['wallet-1']?.lockedUntil,
        afterSecondLock.add(const Duration(minutes: 10)),
      );
    },
  );

  test(
    'recordFailure does not complete before persistence completes',
    () async {
      final store = _DelayedPasswordAttemptStore();
      final limiter = PasswordAttemptLimiter(store: store);

      var completed = false;
      final operation = limiter
          .recordFailure(
            walletId: 'wallet-1',
            now: DateTime.utc(2026, 8, 2, 12),
          )
          .then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      store.completeWrite();
      await operation;
      expect(completed, isTrue);
    },
  );

  test('recordSuccess does not complete before removal completes', () async {
    final store = _DelayedPasswordAttemptStore();
    final limiter = PasswordAttemptLimiter(store: store);

    var completed = false;
    final operation = limiter
        .recordSuccess('wallet-1')
        .then((_) => completed = true);

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    store.completeRemove();
    await operation;
    expect(completed, isTrue);
  });
}

final class _MemoryPasswordAttemptStore implements PasswordAttemptStore {
  final states = <String, PasswordAttemptSnapshot>{};

  @override
  PasswordAttemptSnapshot? read(String walletId) => states[walletId];

  @override
  Future<void> remove(String walletId) async {
    states.remove(walletId);
  }

  @override
  Future<void> write(String walletId, PasswordAttemptSnapshot snapshot) async {
    states[walletId] = snapshot;
  }
}

final class _DelayedPasswordAttemptStore implements PasswordAttemptStore {
  final _writeCompleter = Completer<void>();
  final _removeCompleter = Completer<void>();

  @override
  PasswordAttemptSnapshot? read(String walletId) => null;

  @override
  Future<void> remove(String walletId) => _removeCompleter.future;

  @override
  Future<void> write(String walletId, PasswordAttemptSnapshot snapshot) =>
      _writeCompleter.future;

  void completeWrite() => _writeCompleter.complete();

  void completeRemove() => _removeCompleter.complete();
}
