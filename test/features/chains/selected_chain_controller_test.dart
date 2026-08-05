import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/application/selected_chain_controller.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';

void main() {
  test('selected chain controller loads and switches the active chain',
      () async {
    final repository = _FakeChainRepository();
    final container = ProviderContainer(
      overrides: [chainRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final availableChains =
        await container.read(availableChainsProvider.future);
    final initialChain =
        await container.read(selectedChainControllerProvider.future);

    expect(availableChains, defaultChains);
    expect(initialChain.id, 'ethereum');

    await container
        .read(selectedChainControllerProvider.notifier)
        .selectChain('solana-devnet');

    final selected = container.read(selectedChainControllerProvider).value;

    expect(selected?.id, 'solana-devnet');
    expect(repository.selectedChainId, 'solana-devnet');
  });
}

final class _FakeChainRepository implements ChainRepository {
  String selectedChainId = 'ethereum';

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }
}
