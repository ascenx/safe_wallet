import '../../chains/domain/chain_config.dart';

const wrappedSolMintAddress = 'So11111111111111111111111111111111111111112';

enum WrappedNativeOperation { wrap, unwrap }

final class WrappedNativeConfig {
  const WrappedNativeConfig({
    required this.chainId,
    required this.chainType,
    required this.nativeSymbol,
    required this.wrappedSymbol,
    required this.wrappedName,
    required this.wrappedAssetAddress,
    required this.decimals,
  });

  final String chainId;
  final ChainType chainType;
  final String nativeSymbol;
  final String wrappedSymbol;
  final String wrappedName;
  final String wrappedAssetAddress;
  final int decimals;
}

final class EvmWrappedNativeCall {
  const EvmWrappedNativeCall({
    required this.contractAddress,
    required this.calldata,
    required this.valueWei,
  });

  final String contractAddress;
  final String calldata;
  final BigInt valueWei;
}

WrappedNativeConfig? wrappedNativeConfigFor(ChainConfig chain) {
  final config = _configs[chain.chainId];
  if (config == null || config.chainType != chain.chainType) {
    return null;
  }
  return config;
}

EvmWrappedNativeCall buildEvmWrappedNativeCall({
  required WrappedNativeConfig config,
  required WrappedNativeOperation operation,
  required BigInt amountInBaseUnits,
}) {
  if (config.chainType != ChainType.evm) {
    throw ArgumentError.value(config.chainType, 'config', 'must be EVM');
  }
  if (amountInBaseUnits <= BigInt.zero) {
    throw ArgumentError.value(
      amountInBaseUnits,
      'amountInBaseUnits',
      'must be positive',
    );
  }
  return switch (operation) {
    WrappedNativeOperation.wrap => EvmWrappedNativeCall(
      contractAddress: config.wrappedAssetAddress,
      calldata: '0xd0e30db0',
      valueWei: amountInBaseUnits,
    ),
    WrappedNativeOperation.unwrap => EvmWrappedNativeCall(
      contractAddress: config.wrappedAssetAddress,
      calldata:
          '0x2e1a7d4d${amountInBaseUnits.toRadixString(16).padLeft(64, '0')}',
      valueWei: BigInt.zero,
    ),
  };
}

BigInt? parseWrappedNativeAmount(String value, {required int decimals}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.startsWith('-') || decimals < 0) {
    return null;
  }
  final parts = trimmed.split('.');
  if (parts.length > 2) {
    return null;
  }
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';
  if (!RegExp(r'^\d+$').hasMatch(whole) ||
      (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction)) ||
      fraction.length > decimals) {
    return null;
  }
  final base = BigInt.from(10).pow(decimals);
  final wholeUnits = BigInt.parse(whole) * base;
  final paddedFraction = fraction.padRight(decimals, '0');
  final fractionUnits = paddedFraction.isEmpty
      ? BigInt.zero
      : BigInt.parse(paddedFraction);
  return wholeUnits + fractionUnits;
}

String formatWrappedNativeAmount(BigInt value, {required int decimals}) {
  if (decimals <= 0) {
    return value.toString();
  }
  final negative = value.isNegative;
  final absolute = value.abs();
  final base = BigInt.from(10).pow(decimals);
  final whole = absolute ~/ base;
  final fraction = (absolute % base)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final sign = negative ? '-' : '';
  return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
}

const _configs = <String, WrappedNativeConfig>{
  '1': WrappedNativeConfig(
    chainId: '1',
    chainType: ChainType.evm,
    nativeSymbol: 'ETH',
    wrappedSymbol: 'WETH',
    wrappedName: 'Wrapped Ether',
    wrappedAssetAddress: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    decimals: 18,
  ),
  '56': WrappedNativeConfig(
    chainId: '56',
    chainType: ChainType.evm,
    nativeSymbol: 'BNB',
    wrappedSymbol: 'WBNB',
    wrappedName: 'Wrapped BNB',
    wrappedAssetAddress: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    decimals: 18,
  ),
  '137': WrappedNativeConfig(
    chainId: '137',
    chainType: ChainType.evm,
    nativeSymbol: 'POL',
    wrappedSymbol: 'WPOL',
    wrappedName: 'Wrapped POL',
    wrappedAssetAddress: '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270',
    decimals: 18,
  ),
  '42161': WrappedNativeConfig(
    chainId: '42161',
    chainType: ChainType.evm,
    nativeSymbol: 'ETH',
    wrappedSymbol: 'WETH',
    wrappedName: 'Wrapped Ether',
    wrappedAssetAddress: '0x82af49447d8a07e3bd95bd0d56f35241523fbab1',
    decimals: 18,
  ),
  '10': WrappedNativeConfig(
    chainId: '10',
    chainType: ChainType.evm,
    nativeSymbol: 'ETH',
    wrappedSymbol: 'WETH',
    wrappedName: 'Wrapped Ether',
    wrappedAssetAddress: '0x4200000000000000000000000000000000000006',
    decimals: 18,
  ),
  '8453': WrappedNativeConfig(
    chainId: '8453',
    chainType: ChainType.evm,
    nativeSymbol: 'ETH',
    wrappedSymbol: 'WETH',
    wrappedName: 'Wrapped Ether',
    wrappedAssetAddress: '0x4200000000000000000000000000000000000006',
    decimals: 18,
  ),
  '999': WrappedNativeConfig(
    chainId: '999',
    chainType: ChainType.evm,
    nativeSymbol: 'HYPE',
    wrappedSymbol: 'WHYPE',
    wrappedName: 'Wrapped HYPE',
    wrappedAssetAddress: '0x5555555555555555555555555555555555555555',
    decimals: 18,
  ),
  'mainnet-beta': WrappedNativeConfig(
    chainId: 'mainnet-beta',
    chainType: ChainType.solana,
    nativeSymbol: 'SOL',
    wrappedSymbol: 'WSOL',
    wrappedName: 'Wrapped SOL',
    wrappedAssetAddress: wrappedSolMintAddress,
    decimals: 9,
  ),
  'devnet': WrappedNativeConfig(
    chainId: 'devnet',
    chainType: ChainType.solana,
    nativeSymbol: 'SOL',
    wrappedSymbol: 'WSOL',
    wrappedName: 'Wrapped SOL',
    wrappedAssetAddress: wrappedSolMintAddress,
    decimals: 9,
  ),
};
