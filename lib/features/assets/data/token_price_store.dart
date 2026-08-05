abstract interface class TokenPriceStore {
  Future<Map<String, TokenPriceCacheEntry>> getAll(Iterable<String> keys);

  Future<void> putAll(Map<String, TokenPriceCacheEntry> entries);
}

final class InMemoryTokenPriceStore implements TokenPriceStore {
  InMemoryTokenPriceStore([Map<String, TokenPriceCacheEntry>? entries])
      : _entries = Map.of(entries ?? const {});

  final Map<String, TokenPriceCacheEntry> _entries;

  @override
  Future<Map<String, TokenPriceCacheEntry>> getAll(
      Iterable<String> keys) async {
    return {
      for (final key in keys)
        if (_entries[key] != null) key: _entries[key]!,
    };
  }

  @override
  Future<void> putAll(Map<String, TokenPriceCacheEntry> entries) async {
    _entries.addAll(entries);
  }
}

enum TokenPriceSource {
  coinGecko,
  defiLlama,
  jupiter,
}

final class TokenPriceQuote {
  const TokenPriceQuote({
    required this.priceUsd,
    required this.source,
    required this.updatedAt,
  });

  final double priceUsd;
  final TokenPriceSource source;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TokenPriceQuote &&
            other.priceUsd == priceUsd &&
            other.source == source &&
            other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(priceUsd, source, updatedAt);
}

final class TokenPriceCacheEntry {
  const TokenPriceCacheEntry({
    required this.quote,
    required this.expiresAt,
  });

  final TokenPriceQuote quote;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TokenPriceCacheEntry &&
            other.quote == quote &&
            other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(quote, expiresAt);
}
