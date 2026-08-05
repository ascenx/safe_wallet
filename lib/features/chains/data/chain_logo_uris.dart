import '../domain/chain_config.dart';

const chainLogoAssetBase = 'asset:assets/chain_logos';

String? chainLogoUri(ChainConfig chain) {
  return switch (chain.id) {
    'ethereum' => '$chainLogoAssetBase/ethereum.svg',
    'bnb-smart-chain' => '$chainLogoAssetBase/bnb-smart-chain.svg',
    'polygon' => '$chainLogoAssetBase/polygon.svg',
    'arbitrum' => '$chainLogoAssetBase/arbitrum.svg',
    'optimism' => '$chainLogoAssetBase/optimism.svg',
    'base' => '$chainLogoAssetBase/base.svg',
    'hyperevm' => '$chainLogoAssetBase/hyperevm.svg',
    'bitcoin-mainnet' => '$chainLogoAssetBase/bitcoin.svg',
    'solana-mainnet' || 'solana-devnet' => '$chainLogoAssetBase/solana.svg',
    'tron-mainnet' => '$chainLogoAssetBase/tron.svg',
    'sui-mainnet' ||
    'sui-testnet' ||
    'sui-devnet' =>
      '$chainLogoAssetBase/sui.svg',
    _ => null,
  };
}
