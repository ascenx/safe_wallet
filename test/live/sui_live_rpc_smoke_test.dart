import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/data/sui_asset_service.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/shared/chain_clients/sui_client_factory.dart';

void main() {
  const enabled = bool.hasEnvironment('SAFE_WALLET_LIVE_SUI_RPC')
      ? bool.fromEnvironment('SAFE_WALLET_LIVE_SUI_RPC')
      : false;
  final skipReason = enabled
      ? false
      : 'Set SAFE_WALLET_LIVE_SUI_RPC=true to run Sui gRPC smoke tests.';

  test(
    'queries Sui mainnet checkpoint, balance, and native Coin metadata',
    () async {
      final chain =
          defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
      final rpcUrl = chain.rpcUrls.first;
      final serviceInfo =
          await const GrpcSuiClientFactory().getServiceInfo(rpcUrl);
      final assetService = GrpcSuiAssetService();
      addTearDown(assetService.close);

      final balance = await assetService.getBalance(
        rpcUrl: rpcUrl,
        owner:
            '0x0000000000000000000000000000000000000000000000000000000000000000',
      );
      final metadata = await assetService.getCoinMetadata(
        rpcUrl: rpcUrl,
        coinType: suiNativeCoinType,
      );

      expect(serviceInfo.chainIdentifier, suiMainnetChainIdentifier);
      expect(serviceInfo.checkpointHeight, greaterThan(0));
      expect(balance.coinType, suiNativeCoinType);
      expect(balance.totalBalance, isNonNegative);
      expect(metadata?.symbol, 'SUI');
      expect(metadata?.decimals, 9);
    },
    skip: skipReason,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
