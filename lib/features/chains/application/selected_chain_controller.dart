import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transfer/application/fee_estimate_provider.dart';
import '../domain/chain_config.dart';
import 'available_chains_provider.dart';

final selectedChainControllerProvider =
    AsyncNotifierProvider<SelectedChainController, ChainConfig>(
  SelectedChainController.new,
);

final class SelectedChainController extends AsyncNotifier<ChainConfig> {
  @override
  Future<ChainConfig> build() {
    return ref.read(chainRepositoryProvider).getSelectedChain();
  }

  Future<void> selectChain(String chainId) async {
    state = const AsyncLoading();
    final selected =
        await ref.read(chainRepositoryProvider).selectChain(chainId);
    ref.invalidate(availableChainsProvider);
    ref.read(feeEstimateInvalidationProvider.notifier).bump();
    state = AsyncData(selected);
  }
}
