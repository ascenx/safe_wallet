import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../domain/dapp_recent_visit.dart';

final browserStateRepositoryProvider = Provider<BrowserStateRepository>((ref) {
  return InMemoryBrowserStateRepository();
});

abstract interface class BrowserStateRepository {
  Future<Set<String>> favoriteDappIds();

  Future<void> saveFavoriteDappIds(Set<String> ids);

  Future<List<DappRecentVisit>> favoriteVisits();

  Future<void> saveFavoriteVisits(List<DappRecentVisit> visits);

  Future<List<DappRecentVisit>> recentVisits();

  Future<void> saveRecentVisit(DappRecentVisit visit);
}

final class HiveBrowserStateRepository implements BrowserStateRepository {
  HiveBrowserStateRepository({
    required HiveBoxRegistry registry,
    this.maxRecentVisits = 8,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  static const _favoriteDappIdsKey = 'favoriteDappIds';
  static const _favoriteVisitsKey = 'favoriteVisits';
  static const _recentVisitsKey = 'recentVisits';

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;
  final int maxRecentVisits;

  @override
  Future<Set<String>> favoriteDappIds() async {
    final rawValue = _registry.browserStateBox.get(_favoriteDappIdsKey);
    if (rawValue is! String) {
      return const {};
    }
    final json = _codec.tryDecode(rawValue, (value) => value);
    if (json == null) {
      return const {};
    }
    final ids = json['ids'];
    if (ids is! List) {
      return const {};
    }
    return ids.whereType<String>().toSet();
  }

  @override
  Future<void> saveFavoriteDappIds(Set<String> ids) async {
    await _registry.browserStateBox.put(
      _favoriteDappIdsKey,
      _codec.encode({'ids': ids.toList()..sort()}),
    );
  }

  @override
  Future<List<DappRecentVisit>> favoriteVisits() {
    return _readVisits(_favoriteVisitsKey);
  }

  @override
  Future<void> saveFavoriteVisits(List<DappRecentVisit> visits) async {
    await _registry.browserStateBox.put(
      _favoriteVisitsKey,
      _codec.encode({'items': visits.map(_visitToJson).toList()}),
    );
  }

  @override
  Future<List<DappRecentVisit>> recentVisits() async {
    final visits = await _readVisits(_recentVisitsKey);
    return List.unmodifiable(visits.take(maxRecentVisits));
  }

  Future<List<DappRecentVisit>> _readVisits(String key) async {
    final rawValue = _registry.browserStateBox.get(key);
    if (rawValue is! String) {
      return const [];
    }
    final json = _codec.tryDecode(rawValue, (value) => value);
    if (json == null) {
      return const [];
    }
    final items = json['items'];
    if (items is! List) {
      return const [];
    }
    final visits =
        items
            .whereType<Map>()
            .map((value) {
              try {
                return _visitFromJson(value.cast<String, Object?>());
              } catch (_) {
                return null;
              }
            })
            .whereType<DappRecentVisit>()
            .toList()
          ..sort(_newestFirst);
    return List.unmodifiable(visits);
  }

  @override
  Future<void> saveRecentVisit(DappRecentVisit visit) async {
    final visits = await recentVisits();
    final next = [
      visit,
      ...visits.where((existing) => existing.domain != visit.domain),
    ]..sort(_newestFirst);
    await _registry.browserStateBox.put(
      _recentVisitsKey,
      _codec.encode({
        'items': next.take(maxRecentVisits).map(_visitToJson).toList(),
      }),
    );
  }

  int _newestFirst(DappRecentVisit left, DappRecentVisit right) {
    return right.visitedAt.compareTo(left.visitedAt);
  }

  Map<String, Object?> _visitToJson(DappRecentVisit visit) {
    return {
      'domain': visit.domain,
      'title': visit.title,
      'url': visit.url,
      'visitedAt': visit.visitedAt.toIso8601String(),
    };
  }

  DappRecentVisit _visitFromJson(Map<String, Object?> json) {
    return DappRecentVisit(
      domain: json['domain'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      visitedAt: DateTime.parse(json['visitedAt'] as String),
    );
  }
}

final class InMemoryBrowserStateRepository implements BrowserStateRepository {
  final Set<String> _favoriteIds = {};
  final List<DappRecentVisit> _favoriteVisits = [];
  final List<DappRecentVisit> _visits = [];

  @override
  Future<Set<String>> favoriteDappIds() async {
    return Set.unmodifiable(_favoriteIds);
  }

  @override
  Future<void> saveFavoriteDappIds(Set<String> ids) async {
    _favoriteIds
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<List<DappRecentVisit>> favoriteVisits() async {
    return List.unmodifiable(_favoriteVisits);
  }

  @override
  Future<void> saveFavoriteVisits(List<DappRecentVisit> visits) async {
    _favoriteVisits
      ..clear()
      ..addAll(visits);
  }

  @override
  Future<List<DappRecentVisit>> recentVisits() async {
    return List.unmodifiable(_visits);
  }

  @override
  Future<void> saveRecentVisit(DappRecentVisit visit) async {
    _visits.removeWhere((existing) => existing.domain == visit.domain);
    _visits.insert(0, visit);
  }
}
