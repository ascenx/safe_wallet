import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_browser_state_repository.dart';
import '../domain/dapp_recent_visit.dart';

final dappFavoritesControllerProvider =
    AsyncNotifierProvider<DappFavoritesController, Set<String>>(
  DappFavoritesController.new,
);

final dappFavoriteVisitsControllerProvider =
    AsyncNotifierProvider<DappFavoriteVisitsController, List<DappRecentVisit>>(
  DappFavoriteVisitsController.new,
);

final class DappFavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    return ref.watch(browserStateRepositoryProvider).favoriteDappIds();
  }

  Future<void> favorite(String dappId) async {
    final ids = {...await future, dappId};
    await _save(ids);
  }

  Future<void> unfavorite(String dappId) async {
    final ids = {...await future}..remove(dappId);
    await _save(ids);
  }

  Future<void> toggleFavorite(String dappId) async {
    final ids = {...await future};
    if (!ids.remove(dappId)) {
      ids.add(dappId);
    }
    await _save(ids);
  }

  Future<void> _save(Set<String> ids) async {
    state = AsyncData(Set.unmodifiable(ids));
    await ref.read(browserStateRepositoryProvider).saveFavoriteDappIds(ids);
    ref.invalidateSelf();
  }
}

final class DappFavoriteVisitsController
    extends AsyncNotifier<List<DappRecentVisit>> {
  @override
  Future<List<DappRecentVisit>> build() {
    return ref.watch(browserStateRepositoryProvider).favoriteVisits();
  }

  Future<void> toggle(DappRecentVisit visit) async {
    final visits = [...await future];
    final existingIndex = visits.indexWhere(
      (existing) => existing.domain == visit.domain,
    );
    if (existingIndex >= 0) {
      visits.removeAt(existingIndex);
    } else {
      visits.insert(0, visit);
    }
    final next = List<DappRecentVisit>.unmodifiable(visits);
    state = AsyncData(next);
    await ref.read(browserStateRepositoryProvider).saveFavoriteVisits(next);
  }
}
