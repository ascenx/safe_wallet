import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_repository_provider.dart';

final hiddenTokensControllerProvider =
    AsyncNotifierProvider<HiddenTokensController, void>(
  HiddenTokensController.new,
);

final class HiddenTokensController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> hide({
    required String chainId,
    required String contractAddress,
  }) async {
    state = const AsyncLoading();
    await ref.read(tokenRepositoryProvider).hideToken(
          chainId: chainId,
          contractAddress: contractAddress,
        );
    ref.invalidate(tokensForChainProvider(chainId));
    ref.invalidate(allTokensForChainProvider(chainId));
    state = const AsyncData(null);
  }

  Future<void> unhide({
    required String chainId,
    required String contractAddress,
  }) async {
    state = const AsyncLoading();
    await ref.read(tokenRepositoryProvider).unhideToken(
          chainId: chainId,
          contractAddress: contractAddress,
        );
    ref.invalidate(tokensForChainProvider(chainId));
    ref.invalidate(allTokensForChainProvider(chainId));
    state = const AsyncData(null);
  }
}
