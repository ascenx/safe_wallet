import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_portfolio_provider.dart';

final assetRefreshControllerProvider =
    AsyncNotifierProvider<AssetRefreshController, void>(
  AssetRefreshController.new,
);

final class AssetRefreshController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final request = await ref.read(assetPortfolioRequestProvider);
      if (request != null) {
        ref
            .read(assetPortfolioLiveRefreshRegistryProvider)
            .forceNext(assetPortfolioLiveRefreshKey(request));
      }
      final _ = await ref.refresh(assetPortfolioProvider.future);
    });
  }
}
