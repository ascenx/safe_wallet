import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/wallet/data/security_logging_wallet_repository.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  group('SecurityLoggingWalletRepository', () {
    test('records successful security-sensitive wallet operations', () async {
      final logRepository = InMemorySecurityLogRepository();
      final repository = SecurityLoggingWalletRepository(
        delegate: _FakeWalletRepository(),
        securityLogRepository: logRepository,
      );

      await repository.createWallet(password: 'password');
      await repository.importMnemonicWallet(
        mnemonic: 'mnemonic',
        password: 'password',
      );
      await repository.importPrivateKeyWallet(
        privateKey: 'private-key',
        password: 'password',
      );
      await repository.exportSecret(
        walletId: 'wallet-1',
        password: 'password',
        secretType: WalletSecretType.mnemonic,
      );
      await repository.exportSecret(
        walletId: 'wallet-1',
        password: 'password',
        secretType: WalletSecretType.evmPrivateKey,
      );
      await repository.deleteWallet(
        walletId: 'wallet-1',
        password: 'password',
      );
      await repository.changePassword(
        walletId: 'wallet-1',
        currentPassword: 'password',
        newPassword: 'new-password',
      );

      final entries = await logRepository.listEntries();
      expect(
        entries.map((entry) => entry.type),
        containsAllInOrder([
          SecurityLogEventType.createWallet,
          SecurityLogEventType.importWallet,
          SecurityLogEventType.importWallet,
          SecurityLogEventType.viewMnemonic,
          SecurityLogEventType.viewPrivateKey,
          SecurityLogEventType.deleteWallet,
          SecurityLogEventType.changePassword,
        ].reversed),
      );
      final viewedMnemonic = entries.firstWhere(
        (entry) => entry.type == SecurityLogEventType.viewMnemonic,
      );
      expect(viewedMnemonic.walletName, 'Wallet 1');
      expect(viewedMnemonic.chainName, isNull);
      final viewedPrivateKey = entries.firstWhere(
        (entry) => entry.type == SecurityLogEventType.viewPrivateKey,
      );
      expect(viewedPrivateKey.walletName, 'Wallet 1');
      expect(viewedPrivateKey.chainName, 'EVM');
    });

    test('does not record failed operations', () async {
      final logRepository = InMemorySecurityLogRepository();
      final repository = SecurityLoggingWalletRepository(
        delegate: _FakeWalletRepository(failCreate: true),
        securityLogRepository: logRepository,
      );

      await expectLater(
        repository.createWallet(password: 'password'),
        throwsStateError,
      );

      expect(await logRepository.listEntries(), isEmpty);
    });
  });
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({this.failCreate = false});

  final bool failCreate;

  static final account = WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: DateTime.utc(2026, 7, 31),
    updatedAt: DateTime.utc(2026, 7, 31),
  );

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    if (failCreate) {
      throw StateError('create failed');
    }
    return account;
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async =>
      account;

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async =>
      account;

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {}

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async =>
      'secret';

  @override
  Future<List<WalletAccount>> getWallets() async => [account];

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async =>
      WalletKeyMaterial();

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) async =>
      account;

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async =>
      WalletUnlockResult(account: account, walletDek: const [1, 2, 3]);
}
