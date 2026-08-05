import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('SessionKeyCache', () {
    final baseTime = DateTime.utc(2026, 6, 6, 12);

    test('returns key after unlock and hides it after timeout', () {
      final cache = SessionKeyCache(
        timeout: const Duration(minutes: 15),
      );

      cache.unlock(
        walletId: 'wallet-1',
        walletDek: [1, 2, 3, 4],
        now: baseTime,
      );

      expect(
        cache.readKey('wallet-1',
            now: baseTime.add(const Duration(minutes: 14))),
        [1, 2, 3, 4],
      );
      expect(
        cache.readKey('wallet-1',
            now: baseTime.add(const Duration(minutes: 16))),
        isNull,
      );
    });

    test('touch extends key validity', () {
      final cache = SessionKeyCache(timeout: const Duration(minutes: 15));
      cache.unlock(walletId: 'wallet-1', walletDek: [1, 2, 3], now: baseTime);

      cache.touch(now: baseTime.add(const Duration(minutes: 10)));

      expect(
        cache.readKey('wallet-1',
            now: baseTime.add(const Duration(minutes: 24))),
        [1, 2, 3],
      );
      expect(
        cache.readKey('wallet-1',
            now: baseTime.add(const Duration(minutes: 26))),
        isNull,
      );
    });

    test('clear removes the key immediately', () {
      final cache = SessionKeyCache(timeout: const Duration(minutes: 15));
      cache.unlock(walletId: 'wallet-1', walletDek: [1, 2, 3], now: baseTime);

      cache.clear();

      expect(cache.readKey('wallet-1', now: baseTime), isNull);
    });

    test('keeps keys for multiple wallets in the same session', () {
      final cache = SessionKeyCache(timeout: const Duration(minutes: 15));

      cache.unlock(
        walletId: 'wallet-1',
        walletDek: [1, 2, 3],
        now: baseTime,
      );
      cache.unlock(
        walletId: 'wallet-2',
        walletDek: [4, 5, 6],
        now: baseTime,
      );

      expect(cache.readKey('wallet-1', now: baseTime), [1, 2, 3]);
      expect(cache.readKey('wallet-2', now: baseTime), [4, 5, 6]);
    });

    test('default session expires after fifteen minutes', () {
      final cache = SessionKeyCache();

      cache.unlock(
        walletId: 'wallet-1',
        walletDek: [1, 2, 3],
        now: baseTime,
      );

      expect(
        cache.readKey(
          'wallet-1',
          now: baseTime.add(const Duration(minutes: 14)),
        ),
        [1, 2, 3],
      );
      expect(
        cache.readKey(
          'wallet-1',
          now: baseTime.add(const Duration(minutes: 15)),
        ),
        isNull,
      );
    });
  });
}
