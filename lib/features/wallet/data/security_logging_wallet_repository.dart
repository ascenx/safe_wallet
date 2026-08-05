import '../../settings/data/security_log_repository.dart';
import '../../settings/domain/security_log_entry.dart';
import '../domain/wallet_account.dart';
import 'wallet_repository.dart';

final class SecurityLoggingWalletRepository implements WalletRepository {
  const SecurityLoggingWalletRepository({
    required WalletRepository delegate,
    required SecurityLogRepository securityLogRepository,
  })  : _delegate = delegate,
        _securityLogRepository = securityLogRepository;

  final WalletRepository _delegate;
  final SecurityLogRepository _securityLogRepository;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    final account = await _delegate.createWallet(
      password: password,
      name: name,
    );
    await _record(
      SecurityLogEventType.createWallet,
      walletName: account.name,
    );
    return account;
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async {
    final account = await _delegate.importMnemonicWallet(
      mnemonic: mnemonic,
      password: password,
      name: name,
    );
    await _record(
      SecurityLogEventType.importWallet,
      walletName: account.name,
    );
    return account;
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async {
    final account = await _delegate.importPrivateKeyWallet(
      privateKey: privateKey,
      password: password,
      name: name,
      chain: chain,
    );
    await _record(
      SecurityLogEventType.importWallet,
      walletName: account.name,
      chainName: _privateKeyChainName(chain),
    );
    return account;
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    final walletName = await _walletNameFor(walletId);
    await _delegate.deleteWallet(walletId: walletId, password: password);
    await _record(
      SecurityLogEventType.deleteWallet,
      walletName: walletName,
    );
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final walletName = await _walletNameFor(walletId);
    await _delegate.changePassword(
      walletId: walletId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _record(
      SecurityLogEventType.changePassword,
      walletName: walletName,
    );
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async {
    final walletName = await _walletNameFor(walletId);
    final secret = await _delegate.exportSecret(
      walletId: walletId,
      password: password,
      secretType: secretType,
    );
    await _record(
      secretType == WalletSecretType.mnemonic
          ? SecurityLogEventType.viewMnemonic
          : SecurityLogEventType.viewPrivateKey,
      walletName: walletName,
      chainName: _secretChainName(secretType),
    );
    return secret;
  }

  @override
  Future<List<WalletAccount>> getWallets() => _delegate.getWallets();

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    return _delegate.renameWallet(walletId: walletId, name: name);
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    return _delegate.readKeyMaterial(walletId: walletId, walletDek: walletDek);
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) {
    return _delegate.unlock(walletId: walletId, password: password);
  }

  Future<String?> _walletNameFor(String walletId) async {
    try {
      final wallets = await _delegate.getWallets();
      return wallets.where((wallet) => wallet.id == walletId).firstOrNull?.name;
    } catch (_) {
      return null;
    }
  }

  String? _secretChainName(WalletSecretType secretType) {
    return switch (secretType) {
      WalletSecretType.mnemonic => null,
      WalletSecretType.evmPrivateKey => 'EVM',
      WalletSecretType.btcPrivateKey => 'Bitcoin',
      WalletSecretType.tronPrivateKey => 'Tron',
      WalletSecretType.solanaPrivateKey => 'Solana',
      WalletSecretType.suiPrivateKey => 'Sui',
    };
  }

  String _privateKeyChainName(WalletPrivateKeyChain chain) {
    return switch (chain) {
      WalletPrivateKeyChain.evm => 'EVM',
      WalletPrivateKeyChain.bitcoin => 'Bitcoin',
      WalletPrivateKeyChain.tron => 'Tron',
      WalletPrivateKeyChain.solana => 'Solana',
      WalletPrivateKeyChain.sui => 'Sui',
    };
  }

  Future<void> _record(
    SecurityLogEventType type, {
    String? walletName,
    String? chainName,
  }) async {
    try {
      await _securityLogRepository.record(
        type,
        walletName: walletName,
        chainName: chainName,
      );
    } catch (_) {
      // Logging must never change the result of the wallet operation itself.
    }
  }
}
