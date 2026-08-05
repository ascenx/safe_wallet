import '../../chains/domain/chain_config.dart';
import '../domain/token_info.dart';

abstract interface class TokenBalanceStore {
  Future<Map<String, TokenBalanceCacheEntry>> getAll(Iterable<String> keys);

  Future<void> putAll(Map<String, TokenBalanceCacheEntry> entries);
}

final class NoopTokenBalanceStore implements TokenBalanceStore {
  const NoopTokenBalanceStore();

  @override
  Future<Map<String, TokenBalanceCacheEntry>> getAll(
      Iterable<String> keys) async {
    return const {};
  }

  @override
  Future<void> putAll(Map<String, TokenBalanceCacheEntry> entries) async {}
}

final class InMemoryTokenBalanceStore implements TokenBalanceStore {
  InMemoryTokenBalanceStore([Map<String, TokenBalanceCacheEntry>? entries])
      : _entries = Map.of(entries ?? const {});

  final Map<String, TokenBalanceCacheEntry> _entries;

  @override
  Future<Map<String, TokenBalanceCacheEntry>> getAll(
      Iterable<String> keys) async {
    return {
      for (final key in keys)
        if (_entries[key] != null) key: _entries[key]!,
    };
  }

  @override
  Future<void> putAll(Map<String, TokenBalanceCacheEntry> entries) async {
    _entries.addAll(entries);
  }
}

final class TokenBalanceCacheEntry {
  const TokenBalanceCacheEntry({
    required this.rawBalance,
    required this.formattedBalance,
    required this.updatedAt,
    required this.expiresAt,
  });

  final String rawBalance;
  final String formattedBalance;
  final DateTime updatedAt;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TokenBalanceCacheEntry &&
            other.rawBalance == rawBalance &&
            other.formattedBalance == formattedBalance &&
            other.updatedAt == updatedAt &&
            other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(rawBalance, formattedBalance, updatedAt, expiresAt);
  }
}

String tokenBalanceKey({
  required ChainConfig chain,
  required String walletAddress,
  required TokenInfo token,
}) {
  final normalizedWallet = _normalizeAddress(
    chain: chain,
    address: walletAddress,
  );
  final tokenKey = token.contractAddress == null
      ? 'native'
      : _normalizeAddress(chain: chain, address: token.contractAddress!);
  return '${chain.chainId}:$normalizedWallet:$tokenKey';
}

String _normalizeAddress({
  required ChainConfig chain,
  required String address,
}) {
  return chain.chainType == ChainType.evm ? address.toLowerCase() : address;
}
