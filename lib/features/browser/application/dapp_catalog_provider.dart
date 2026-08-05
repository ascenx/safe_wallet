import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dapp_catalog_repository.dart';
import '../domain/dapp_entry.dart';
import 'dapp_favorites_controller.dart';

final dappCatalogRepositoryProvider = Provider<DappCatalogRepository>((ref) {
  return const DefaultDappCatalogRepository();
});

final dappCatalogProvider = FutureProvider<List<DappEntry>>((ref) async {
  final entries = await ref.watch(dappCatalogRepositoryProvider).listDapps();
  final favoriteIds = await ref.watch(dappFavoritesControllerProvider.future);
  return List.unmodifiable(
    entries.map((entry) {
      return entry.copyWith(isFavorite: favoriteIds.contains(entry.id));
    }),
  );
});
