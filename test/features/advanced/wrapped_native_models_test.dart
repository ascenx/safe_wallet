import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/domain/wrapped_native_models.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';

void main() {
  test(
    'default EVM and Solana chains expose trusted wrapped native configs',
    () {
      final configs = <String, WrappedNativeConfig>{};
      for (final chain in defaultChains) {
        final config = wrappedNativeConfigFor(chain);
        if (config != null) configs[chain.chainId] = config;
      }

      expect(
        configs.keys,
        containsAll(['1', '56', '137', '42161', '10', '8453', '999']),
      );
      expect(configs['1']?.wrappedSymbol, 'WETH');
      expect(configs['56']?.wrappedSymbol, 'WBNB');
      expect(configs['137']?.wrappedSymbol, 'WPOL');
      expect(configs['999']?.wrappedSymbol, 'WHYPE');
      expect(
        configs['mainnet-beta']?.wrappedAssetAddress,
        wrappedSolMintAddress,
      );
      expect(configs['devnet']?.wrappedAssetAddress, wrappedSolMintAddress);
    },
  );

  test('custom EVM chains are unsupported without a trusted config', () {
    const custom = ChainConfig(
      id: 'custom',
      chainType: ChainType.evm,
      name: 'Custom',
      chainId: '123456',
      symbol: 'ETH',
      rpcUrls: ['https://rpc.example.com'],
      blockExplorerUrl: 'https://explorer.example.com',
      isTestnet: false,
    );

    expect(wrappedNativeConfigFor(custom), isNull);
  });

  test(
    'EVM wrap uses deposit calldata and sends the wrapped amount as value',
    () {
      final config = wrappedNativeConfigFor(
        defaultChains.firstWhere((chain) => chain.chainId == '1'),
      )!;

      final call = buildEvmWrappedNativeCall(
        config: config,
        operation: WrappedNativeOperation.wrap,
        amountInBaseUnits: BigInt.from(123),
      );

      expect(call.contractAddress, config.wrappedAssetAddress);
      expect(call.calldata, '0xd0e30db0');
      expect(call.valueWei, BigInt.from(123));
    },
  );

  test('EVM unwrap ABI encodes withdraw uint256 and sends no native value', () {
    final config = wrappedNativeConfigFor(
      defaultChains.firstWhere((chain) => chain.chainId == '1'),
    )!;

    final call = buildEvmWrappedNativeCall(
      config: config,
      operation: WrappedNativeOperation.unwrap,
      amountInBaseUnits: BigInt.one,
    );

    expect(
      call.calldata,
      '0x2e1a7d4d${BigInt.one.toRadixString(16).padLeft(64, '0')}',
    );
    expect(call.valueWei, BigInt.zero);
  });

  test(
    'wrapped native amounts parse and format without floating point loss',
    () {
      final amount = parseWrappedNativeAmount('1.250000001', decimals: 9);

      expect(amount, BigInt.from(1250000001));
      expect(formatWrappedNativeAmount(amount!, decimals: 9), '1.250000001');
      expect(parseWrappedNativeAmount('1.0000000001', decimals: 9), isNull);
      expect(parseWrappedNativeAmount('-1', decimals: 9), isNull);
    },
  );
}
