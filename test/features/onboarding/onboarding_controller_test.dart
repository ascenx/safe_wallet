import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/onboarding/application/onboarding_controller.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('OnboardingController', () {
    test('create wallet unlocks the new wallet session', () async {
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository();
      final container = _container(repository: repository, cache: cache);

      final account = await container
          .read(onboardingControllerProvider.notifier)
          .createWallet(password: 'StrongPass123');

      final session = container.read(walletSessionControllerProvider).value;
      expect(account.id, 'wallet-1');
      expect(container.read(selectedWalletIdProvider), account.id);
      expect(session?.walletId, account.id);
      expect(session?.isUnlocked, isTrue);
      expect(
          cache.readKey(account.id, now: DateTime.now().toUtc()), _walletDek);
      expect(repository.unlockCalls, 1);
    });

    test('import wallet unlocks the imported wallet session', () async {
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository();
      final container = _container(repository: repository, cache: cache);

      final account = await container
          .read(onboardingControllerProvider.notifier)
          .importWallet(
            method: OnboardingImportMethod.mnemonic,
            secret: 'test mnemonic',
            password: 'StrongPass123',
          );

      final session = container.read(walletSessionControllerProvider).value;
      expect(account.id, 'wallet-1');
      expect(container.read(selectedWalletIdProvider), account.id);
      expect(session?.walletId, account.id);
      expect(session?.isUnlocked, isTrue);
      expect(
          cache.readKey(account.id, now: DateTime.now().toUtc()), _walletDek);
      expect(repository.unlockCalls, 1);
    });

    test('import private key passes the selected private key chain', () async {
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository();
      final container = _container(repository: repository, cache: cache);

      await container.read(onboardingControllerProvider.notifier).importWallet(
            method: OnboardingImportMethod.privateKey,
            secret: 'solana-private-key',
            password: 'StrongPass123',
            privateKeyChain: WalletPrivateKeyChain.solana,
          );

      expect(repository.lastImportedPrivateKey, 'solana-private-key');
      expect(
          repository.lastImportedPrivateKeyChain, WalletPrivateKeyChain.solana);
    });

    test('import Bitcoin private key passes the Bitcoin private key chain',
        () async {
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository();
      final container = _container(repository: repository, cache: cache);

      await container.read(onboardingControllerProvider.notifier).importWallet(
            method: OnboardingImportMethod.privateKey,
            secret: 'bitcoin-private-key',
            password: 'StrongPass123',
            privateKeyChain: WalletPrivateKeyChain.bitcoin,
          );

      expect(repository.lastImportedPrivateKey, 'bitcoin-private-key');
      expect(
        repository.lastImportedPrivateKeyChain,
        WalletPrivateKeyChain.bitcoin,
      );
    });

    test('keeps the persisted selected wallet when wallets already exist',
        () async {
      final cache = SessionKeyCache();
      final repository = _FakeWalletRepository();
      final firstAccount = await repository.createWallet(
        password: 'StrongPass123',
        name: 'First Wallet',
      );
      final secondAccount = await repository.createWallet(
        password: 'StrongPass123',
        name: 'Second Wallet',
      );
      final store = InMemorySelectedWalletStore();
      await store.writeSelectedWalletId(secondAccount.id);
      final container = _container(
        repository: repository,
        cache: cache,
        selectedWalletStore: store,
      );

      final state = await container.read(onboardingControllerProvider.future);

      expect(firstAccount.id, 'wallet-1');
      expect(state.account?.id, secondAccount.id);
      expect(container.read(selectedWalletIdProvider), secondAccount.id);
    });
  });
}

ProviderContainer _container({
  required _FakeWalletRepository repository,
  required SessionKeyCache cache,
  SelectedWalletStore? selectedWalletStore,
}) {
  final container = ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      sessionKeyCacheProvider.overrideWithValue(cache),
      if (selectedWalletStore != null)
        selectedWalletStoreProvider.overrideWithValue(selectedWalletStore),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final _now = DateTime.utc(2026, 6, 6);
const _walletDek = [1, 2, 3, 4];

final class _FakeWalletRepository implements WalletRepository {
  final List<WalletAccount> _wallets = [];
  int unlockCalls = 0;
  String? lastImportedPrivateKey;
  WalletPrivateKeyChain? lastImportedPrivateKeyChain;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    final account = _account(name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async {
    final account = _account(name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async {
    lastImportedPrivateKey = privateKey;
    lastImportedPrivateKeyChain = chain;
    final account = _account(name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCalls += 1;
    return WalletUnlockResult(account: _wallets.single, walletDek: _walletDek);
  }

  @override
  Future<List<WalletAccount>> getWallets() async => List.unmodifiable(_wallets);

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

  WalletAccount _account(String name) {
    return WalletAccount(
      id: 'wallet-${_wallets.length + 1}',
      name: name,
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '11111111111111111111111111111111',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: _now,
      updatedAt: _now,
    );
  }
}
