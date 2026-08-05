import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/settings/application/security_log_controller.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  group('SecurityLogController', () {
    test('does not return entries when password verification fails', () async {
      final logs = InMemorySecurityLogRepository();
      await logs.record(SecurityLogEventType.createWallet);
      final walletRepository = _FakeWalletRepository(throwOnUnlock: true);
      final container = _container(logs, walletRepository);

      await expectLater(
        container
            .read(securityLogControllerProvider)
            .loadEntries(password: 'wrong-password'),
        throwsStateError,
      );
    });

    test('verifies the wallet password before returning entries', () async {
      final logs = InMemorySecurityLogRepository();
      await logs.record(
        SecurityLogEventType.copyMnemonic,
        occurredAt: DateTime.utc(2026, 7, 31, 12),
      );
      final walletRepository = _FakeWalletRepository();
      final container = _container(logs, walletRepository);

      final entries = await container
          .read(securityLogControllerProvider)
          .loadEntries(password: 'correct-password');

      expect(walletRepository.lastPassword, 'correct-password');
      expect(entries.single.type, SecurityLogEventType.copyMnemonic);
    });
  });
}

ProviderContainer _container(
  SecurityLogRepository logs,
  WalletRepository walletRepository,
) {
  final container = ProviderContainer(
    overrides: [
      securityLogRepositoryProvider.overrideWithValue(logs),
      walletRepositoryProvider.overrideWithValue(walletRepository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({this.throwOnUnlock = false});

  final bool throwOnUnlock;
  String? lastPassword;

  static final account = WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: DateTime.utc(2026, 7, 31),
    updatedAt: DateTime.utc(2026, 7, 31),
  );

  @override
  Future<List<WalletAccount>> getWallets() async => [account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    lastPassword = password;
    if (throwOnUnlock) {
      throw StateError('invalid password');
    }
    return WalletUnlockResult(account: account, walletDek: const [1, 2, 3]);
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) =>
      throw UnimplementedError();

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) =>
      throw UnimplementedError();

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) =>
      throw UnimplementedError();

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) =>
      throw UnimplementedError();

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) =>
      throw UnimplementedError();
}
