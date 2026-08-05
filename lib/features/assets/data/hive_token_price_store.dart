import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import 'token_price_store.dart';

final class HiveTokenPriceStore implements TokenPriceStore {
  HiveTokenPriceStore({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  })  : _registry = registry,
        _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<Map<String, TokenPriceCacheEntry>> getAll(
      Iterable<String> keys) async {
    final entries = <String, TokenPriceCacheEntry>{};
    for (final key in keys) {
      final entry = _entryForKey(key);
      if (entry != null) {
        entries[key] = entry;
      }
    }
    return entries;
  }

  @override
  Future<void> putAll(Map<String, TokenPriceCacheEntry> entries) async {
    for (final entry in entries.entries) {
      await _registry.tokenPricesBox.put(
        entry.key,
        _codec.encode(_entryToJson(entry.value)),
      );
    }
  }

  TokenPriceCacheEntry? _entryForKey(String key) {
    final rawValue = _registry.tokenPricesBox.get(key);
    if (rawValue is! String) {
      return null;
    }
    try {
      return _entryFromJson(_codec.decode(rawValue));
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _entryToJson(TokenPriceCacheEntry entry) {
    return {
      'priceUsd': entry.quote.priceUsd,
      'source': entry.quote.source.name,
      'updatedAt': entry.quote.updatedAt.toUtc().toIso8601String(),
      'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
    };
  }

  TokenPriceCacheEntry _entryFromJson(Map<String, Object?> json) {
    final priceUsd = json['priceUsd'];
    final source = json['source'];
    final updatedAt = json['updatedAt'];
    final expiresAt = json['expiresAt'];
    if (priceUsd is! num ||
        source is! String ||
        updatedAt is! String ||
        expiresAt is! String) {
      throw const FormatException('Stored token price is incomplete');
    }
    return TokenPriceCacheEntry(
      quote: TokenPriceQuote(
        priceUsd: priceUsd.toDouble(),
        source: TokenPriceSource.values.byName(source),
        updatedAt: DateTime.parse(updatedAt).toUtc(),
      ),
      expiresAt: DateTime.parse(expiresAt).toUtc(),
    );
  }
}
