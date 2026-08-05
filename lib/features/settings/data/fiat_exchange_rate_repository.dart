import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';
import '../application/fiat_currency_setting.dart';

final fiatExchangeRateRepositoryProvider = Provider<FiatExchangeRateRepository>(
  (ref) {
    final repository = DefaultFiatExchangeRateRepository();
    ref.onDispose(repository.close);
    return repository;
  },
);

final fiatExchangeRateProvider =
    FutureProvider.family<double?, AppFiatCurrency>((ref, currency) {
      return ref.watch(fiatExchangeRateRepositoryProvider).getUsdRate(currency);
    });

abstract interface class FiatExchangeRateRepository {
  Future<double?> getUsdRate(AppFiatCurrency currency);
}

final class FiatExchangeRateCacheEntry {
  const FiatExchangeRateCacheEntry({
    required this.rate,
    required this.fetchedAt,
  });

  final double rate;
  final DateTime fetchedAt;

  @override
  bool operator ==(Object other) {
    return other is FiatExchangeRateCacheEntry &&
        other.rate == rate &&
        other.fetchedAt == fetchedAt;
  }

  @override
  int get hashCode => Object.hash(rate, fetchedAt);
}

abstract interface class FiatExchangeRateStore {
  Future<FiatExchangeRateCacheEntry?> read(AppFiatCurrency currency);

  Future<void> write(
    AppFiatCurrency currency,
    FiatExchangeRateCacheEntry entry,
  );
}

final class InMemoryFiatExchangeRateStore implements FiatExchangeRateStore {
  InMemoryFiatExchangeRateStore({
    Map<AppFiatCurrency, FiatExchangeRateCacheEntry> entries = const {},
  }) : _entries = {...entries};

  final Map<AppFiatCurrency, FiatExchangeRateCacheEntry> _entries;

  @override
  Future<FiatExchangeRateCacheEntry?> read(AppFiatCurrency currency) async {
    return _entries[currency];
  }

  @override
  Future<void> write(
    AppFiatCurrency currency,
    FiatExchangeRateCacheEntry entry,
  ) async {
    _entries[currency] = entry;
  }
}

final class HiveFiatExchangeRateStore implements FiatExchangeRateStore {
  HiveFiatExchangeRateStore({required HiveBoxRegistry registry})
    : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<FiatExchangeRateCacheEntry?> read(AppFiatCurrency currency) async {
    final value = _registry.settingsBox.get(_key(currency));
    if (value is! Map) {
      return null;
    }
    final rate = value['rate'];
    final fetchedAt = value['fetchedAt'];
    if (rate is! num || fetchedAt is! String) {
      return null;
    }
    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null || rate <= 0) {
      return null;
    }
    return FiatExchangeRateCacheEntry(
      rate: rate.toDouble(),
      fetchedAt: parsedFetchedAt,
    );
  }

  @override
  Future<void> write(
    AppFiatCurrency currency,
    FiatExchangeRateCacheEntry entry,
  ) {
    return _registry.settingsBox.put(_key(currency), {
      'rate': entry.rate,
      'fetchedAt': entry.fetchedAt.toIso8601String(),
    });
  }

  String _key(AppFiatCurrency currency) {
    return '${StorageKeys.fiatExchangeRatePrefix}${currency.code}';
  }
}

final class DefaultFiatExchangeRateRepository
    implements FiatExchangeRateRepository {
  DefaultFiatExchangeRateRepository({
    http.Client? client,
    FiatExchangeRateStore? store,
    Duration cacheTtl = const Duration(hours: 12),
    DateTime Function()? now,
  }) : _client = client ?? BoundedHttpClient(),
       _store = store ?? InMemoryFiatExchangeRateStore(),
       _cacheTtl = cacheTtl,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final FiatExchangeRateStore _store;
  final Duration _cacheTtl;
  final DateTime Function() _now;

  void close() {
    _client.close();
  }

  @override
  Future<double?> getUsdRate(AppFiatCurrency currency) async {
    if (currency == AppFiatCurrency.usd) {
      return 1;
    }

    final cached = await _store.read(currency);
    final now = _now();
    if (cached != null && now.difference(cached.fetchedAt) < _cacheTtl) {
      return cached.rate;
    }

    final fetched = await _fetchUsdRate(currency);
    if (fetched == null) {
      return cached?.rate;
    }

    await _store.write(
      currency,
      FiatExchangeRateCacheEntry(rate: fetched, fetchedAt: now),
    );
    return fetched;
  }

  Future<double?> _fetchUsdRate(AppFiatCurrency currency) async {
    final uri = Uri.https('api.frankfurter.dev', '/v2/rates', {
      'base': AppFiatCurrency.usd.code,
      'quotes': currency.code,
    });
    try {
      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return null;
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic> ||
            item['base'] != AppFiatCurrency.usd.code ||
            item['quote'] != currency.code) {
          continue;
        }
        final rate = item['rate'];
        if (rate is num && rate > 0) {
          return rate.toDouble();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
