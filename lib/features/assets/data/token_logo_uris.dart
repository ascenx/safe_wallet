const tokenLogoAssetBase = 'asset:assets/token_logos';
const ethereumLogoUri = '$tokenLogoAssetBase/eth.svg';
const bnbLogoUri = '$tokenLogoAssetBase/bnb.svg';
const polygonLogoUri = '$tokenLogoAssetBase/polygon.svg';
const solanaLogoUri = '$tokenLogoAssetBase/solana.svg';
const bitcoinLogoUri = 'asset:assets/chain_logos/bitcoin.svg';
const tronLogoUri = 'asset:assets/chain_logos/tron.svg';
const suiLogoUri = 'asset:assets/chain_logos/sui.svg';

String? nativeTokenLogoUri(String chainId) {
  return switch (chainId) {
    '1' || '10' || '42161' || '8453' => ethereumLogoUri,
    '56' => bnbLogoUri,
    '137' => polygonLogoUri,
    'bitcoin-mainnet' => bitcoinLogoUri,
    'mainnet-beta' || 'devnet' => solanaLogoUri,
    'tron-mainnet' => tronLogoUri,
    'sui:mainnet' || 'sui:testnet' || 'sui:devnet' => suiLogoUri,
    _ => null,
  };
}
