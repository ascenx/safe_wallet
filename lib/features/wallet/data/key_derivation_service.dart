import 'dart:typed_data';

import 'package:bip32_plus/bip32_plus.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:solana_sdk/solana_sdk.dart';
import 'package:sui_dart/cryptography/ed25519_keypair.dart' as sui;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart';

final class DerivedWalletAccount {
  DerivedWalletAccount({
    required this.address,
    required List<int> privateKey,
    required this.derivationPath,
  }) : privateKey = List.unmodifiable(privateKey);

  final String address;
  final List<int> privateKey;
  final String derivationPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DerivedWalletAccount &&
            other.address == address &&
            _intListsEqual(other.privateKey, privateKey) &&
            other.derivationPath == derivationPath;
  }

  @override
  int get hashCode {
    return Object.hash(address, Object.hashAll(privateKey), derivationPath);
  }
}

final class KeyDerivationService {
  const KeyDerivationService();

  static String evmPath({int index = 0}) => "m/44'/60'/0'/0/$index";

  static const solanaDefaultPath = "m/44'/501'/0'/0'";
  static const bitcoinDefaultPath = "m/84'/0'/0'/0/0";
  static const tronDefaultPath = "m/44'/195'/0'/0/0";
  static const suiDefaultPath = "m/44'/784'/0'/0'/0'";

  DerivedWalletAccount deriveEvmAccount(Mnemonic mnemonic, {int index = 0}) {
    if (index < 0) {
      throw ArgumentError.value(index, 'index', 'must be non-negative');
    }

    final path = evmPath(index: index);
    final root = BIP32.fromSeed(Uint8List.fromList(mnemonic.seed));
    final child = root.derivePath(path);
    final privateKey = child.privateKey;
    if (privateKey == null) {
      throw StateError('Derived EVM account has no private key');
    }

    final credentials = EthPrivateKey(privateKey);
    return DerivedWalletAccount(
      address: '0x${credentials.address}',
      privateKey: privateKey,
      derivationPath: path,
    );
  }

  DerivedWalletAccount deriveSolanaAccount(Mnemonic mnemonic) {
    final keypair = Keypair.fromSeedAndDerivationPath(
      Uint8List.fromList(mnemonic.seed),
      DerivationPath.fromAbsolutePath(solanaDefaultPath),
    );

    return DerivedWalletAccount(
      address: keypair.publicKey.toBase58(),
      privateKey: keypair.secretKey,
      derivationPath: solanaDefaultPath,
    );
  }

  DerivedWalletAccount deriveBitcoinAccount(Mnemonic mnemonic) {
    final root = wallet.ExtendedPrivateKey.master(
      Uint8List.fromList(mnemonic.seed),
      wallet.zprv,
    );
    final child = root.forPath(bitcoinDefaultPath);
    if (child is! wallet.ExtendedPrivateKey) {
      throw StateError('Derived Bitcoin account has no private key');
    }

    final privateKey = _bigIntToFixedBytes(child.key, 32);
    final bitcoinPrivateKey = wallet.PrivateKey(child.key);
    final publicKey = wallet.bitcoinbech32.createPublicKey(bitcoinPrivateKey);
    return DerivedWalletAccount(
      address: wallet.bitcoinbech32.createAddress(publicKey),
      privateKey: privateKey,
      derivationPath: bitcoinDefaultPath,
    );
  }

  DerivedWalletAccount deriveTronAccount(Mnemonic mnemonic) {
    final root = wallet.ExtendedPrivateKey.master(
      Uint8List.fromList(mnemonic.seed),
      wallet.xprv,
    );
    final child = root.forPath(tronDefaultPath);
    if (child is! wallet.ExtendedPrivateKey) {
      throw StateError('Derived Tron account has no private key');
    }

    final privateKey = _bigIntToFixedBytes(child.key, 32);
    final tronPrivateKey = wallet.PrivateKey(child.key);
    final publicKey = wallet.tron.createPublicKey(tronPrivateKey);
    return DerivedWalletAccount(
      address: wallet.tron.createAddress(publicKey),
      privateKey: privateKey,
      derivationPath: tronDefaultPath,
    );
  }

  DerivedWalletAccount deriveSuiAccount(Mnemonic mnemonic) {
    final keypair = sui.Ed25519Keypair.fromMnemonics(mnemonic.sentence);

    return DerivedWalletAccount(
      address: keypair.getPublicKey().toSuiAddress(),
      privateKey: keypair.getSecretKey(),
      derivationPath: suiDefaultPath,
    );
  }
}

List<int> _bigIntToFixedBytes(BigInt value, int length) {
  final bytes = List<int>.filled(length, 0);
  var remaining = value;
  for (var index = length - 1; index >= 0; index -= 1) {
    bytes[index] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  return bytes;
}

bool _intListsEqual(List<int> left, List<int> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
