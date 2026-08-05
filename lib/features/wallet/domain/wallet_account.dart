import '../../chains/domain/chain_config.dart';

enum WalletAccountSource {
  mnemonic,
  privateKey,
}

final class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.evmAddress,
    this.tronAddress = '',
    required this.solanaAddress,
    this.btcAddress = '',
    this.suiAddress = '',
    this.suiPublicKey = '',
    this.source = WalletAccountSource.mnemonic,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String evmAddress;
  final String tronAddress;
  final String solanaAddress;
  final String btcAddress;
  final String suiAddress;
  final String suiPublicKey;
  final WalletAccountSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WalletAccount &&
            other.id == id &&
            other.name == name &&
            other.evmAddress == evmAddress &&
            other.tronAddress == tronAddress &&
            other.solanaAddress == solanaAddress &&
            other.btcAddress == btcAddress &&
            other.suiAddress == suiAddress &&
            other.suiPublicKey == suiPublicKey &&
            other.source == source &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      evmAddress,
      tronAddress,
      solanaAddress,
      btcAddress,
      suiAddress,
      suiPublicKey,
      source,
      createdAt,
      updatedAt,
    );
  }

  String addressForChainType(ChainType chainType) {
    return switch (chainType) {
      ChainType.evm => evmAddress,
      ChainType.bitcoin => btcAddress,
      ChainType.tron => tronAddress,
      ChainType.solana => solanaAddress,
      ChainType.sui => suiAddress,
    };
  }
}
