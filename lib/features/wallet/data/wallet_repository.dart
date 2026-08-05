import '../domain/wallet_account.dart';

enum WalletSecretType {
  mnemonic,
  evmPrivateKey,
  btcPrivateKey,
  tronPrivateKey,
  solanaPrivateKey,
  suiPrivateKey,
}

enum WalletPrivateKeyChain { evm, bitcoin, tron, solana, sui }

abstract interface class WalletRepository {
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  });

  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  });

  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  });

  Future<List<WalletAccount>> getWallets();

  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  });

  Future<void> deleteWallet({
    required String walletId,
    required String password,
  });

  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  });

  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  });

  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  });

  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  });
}

final class WalletKeyMaterial {
  WalletKeyMaterial({
    this.evmPrivateKey,
    this.btcPrivateKey,
    this.tronPrivateKey,
    List<int>? solanaPrivateKey,
    List<int>? suiPrivateKey,
  }) : solanaPrivateKey = solanaPrivateKey == null
           ? null
           : List.unmodifiable(solanaPrivateKey),
       suiPrivateKey = suiPrivateKey == null
           ? null
           : List.unmodifiable(suiPrivateKey);

  final String? evmPrivateKey;
  final String? btcPrivateKey;
  final String? tronPrivateKey;
  final List<int>? solanaPrivateKey;
  final List<int>? suiPrivateKey;
}

final class WalletUnlockResult {
  WalletUnlockResult({required this.account, required List<int> walletDek})
    : walletDek = List.unmodifiable(walletDek);

  final WalletAccount account;
  final List<int> walletDek;
}
