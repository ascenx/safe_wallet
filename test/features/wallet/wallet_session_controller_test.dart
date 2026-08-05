import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_session.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('WalletSessionController', () {
    final baseTime = DateTime.utc(2026, 6, 6, 12);
    final account = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      createdAt: baseTime,
      updatedAt: baseTime,
    );

    ProviderContainer buildContainer({
      required WalletRepository repository,
      required SessionKeyCache cache,
    }) {
      final container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(repository),
          sessionKeyCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'unlock caches the DEK but exposes only WalletSession state',
      () async {
        final cache = SessionKeyCache();
        final container = buildContainer(
          repository: _FakeWalletRepository(
            unlockResult: WalletUnlockResult(
              account: account,
              walletDek: [1, 2, 3, 4],
            ),
          ),
          cache: cache,
        );

        final session = await container
            .read(walletSessionControllerProvider.notifier)
            .unlock(walletId: account.id, password: 'password', now: baseTime);

        expect(session, isA<WalletSession>());
        expect(session.walletId, account.id);
        expect(session.isUnlocked, isTrue);
        expect(
          session.unlockedUntil,
          baseTime.add(WalletSessionController.unlockDuration),
        );
        expect(cache.readKey(account.id, now: baseTime), [1, 2, 3, 4]);
        expect(session.toString(), isNot(contains('1, 2, 3, 4')));
      },
    );

    test('lock clears the cached DEK and marks session locked', () async {
      final cache = SessionKeyCache(
        timeout: WalletSessionController.unlockDuration,
      );
      final container = buildContainer(
        repository: _FakeWalletRepository(
          unlockResult: WalletUnlockResult(
            account: account,
            walletDek: [1, 2, 3, 4],
          ),
        ),
        cache: cache,
      );

      await container
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: account.id, password: 'password', now: baseTime);

      container.read(walletSessionControllerProvider.notifier).lock();

      final state = container.read(walletSessionControllerProvider).value;
      expect(state?.walletId, account.id);
      expect(state?.isUnlocked, isFalse);
      expect(cache.readKey(account.id, now: baseTime), isNull);
    });

    test('session expiry follows sensitive-operation cache touches', () async {
      final cache = SessionKeyCache(
        timeout: WalletSessionController.unlockDuration,
      );
      final container = buildContainer(
        repository: _FakeWalletRepository(
          unlockResult: WalletUnlockResult(
            account: account,
            walletDek: [1, 2, 3, 4],
          ),
        ),
        cache: cache,
      );
      final controller = container.read(
        walletSessionControllerProvider.notifier,
      );
      await controller.unlock(
        walletId: account.id,
        password: 'password',
        now: baseTime,
      );
      cache.touch(now: baseTime.add(const Duration(minutes: 10)));

      controller.expireIfNeeded(now: baseTime.add(const Duration(minutes: 16)));

      final session = container.read(walletSessionControllerProvider).value;
      expect(session?.isUnlocked, isTrue);
      expect(session?.unlockedUntil, baseTime.add(const Duration(minutes: 25)));
    });

    test('one password unlock caches every local wallet key', () async {
      final secondAccount = WalletAccount(
        id: 'wallet-2',
        name: 'Second Wallet',
        evmAddress: '0x2222222222222222222222222222222222222222',
        solanaAddress: '22222222222222222222222222222222',
        createdAt: baseTime,
        updatedAt: baseTime,
      );
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository(
        unlockResults: {
          account.id: WalletUnlockResult(
            account: account,
            walletDek: [1, 2, 3, 4],
          ),
          secondAccount.id: WalletUnlockResult(
            account: secondAccount,
            walletDek: [5, 6, 7, 8],
          ),
        },
      );
      final container = buildContainer(repository: repository, cache: cache);

      await container
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: account.id, password: 'password', now: baseTime);

      expect(repository.unlockedWalletIds, [account.id, secondAccount.id]);
      expect(cache.readKey(account.id, now: baseTime), [1, 2, 3, 4]);
      expect(cache.readKey(secondAccount.id, now: baseTime), [5, 6, 7, 8]);
    });

    test('biometric keyring restores every local wallet key', () async {
      final cache = SessionKeyCache();
      final container = buildContainer(
        repository: _FakeWalletRepository(
          unlockResult: WalletUnlockResult(
            account: account,
            walletDek: [1, 2, 3, 4],
          ),
        ),
        cache: cache,
      );

      await container
          .read(walletSessionControllerProvider.notifier)
          .unlockWithWalletKeys(
            account: account,
            walletDeks: {
              account.id: [1, 2, 3, 4],
              'wallet-2': [5, 6, 7, 8],
            },
            now: baseTime,
          );

      expect(cache.readKey(account.id, now: baseTime), [1, 2, 3, 4]);
      expect(cache.readKey('wallet-2', now: baseTime), [5, 6, 7, 8]);
    });
  });
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({
    WalletUnlockResult? unlockResult,
    Map<String, WalletUnlockResult>? unlockResults,
  }) : unlockResults = unlockResults ??
            (unlockResult == null
                ? {}
                : {unlockResult.account.id: unlockResult});

  final Map<String, WalletUnlockResult> unlockResults;
  final List<String> unlockedWalletIds = [];

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async =>
      unlockResults.values.map((result) => result.account).toList();

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockedWalletIds.add(walletId);
    return unlockResults[walletId]!;
  }
}
