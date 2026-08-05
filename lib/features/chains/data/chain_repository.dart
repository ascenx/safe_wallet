import '../domain/chain_config.dart';

abstract interface class ChainRepository {
  Future<List<ChainConfig>> getChains();

  Future<ChainConfig> getSelectedChain();

  Future<ChainConfig> selectChain(String chainId);

  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  });
}

abstract interface class RemovableChainRepository {
  Future<void> deleteChain(String chainId);
}
