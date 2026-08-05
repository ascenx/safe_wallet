import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import 'token_balance_store.dart';

final class HiveTokenBalanceStore implements TokenBalanceStore {
  HiveTokenBalanceStore({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  })  : _registry = registry,
        _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<Map<String, TokenBalanceCacheEntry>> getAll(
      Iterable<String> keys) async {
    final entries = <String, TokenBalanceCacheEntry>{};
    for (final key in keys) {
      final entry = _entryForKey(key);
      if (entry != null) {
        entries[key] = entry;
      }
    }
    return entries;
  }

  @override
  Future<void> putAll(Map<String, TokenBalanceCacheEntry> entries) async {
    for (final entry in entries.entries) {
      await _registry.tokenBalancesBox.put(
        entry.key,
        _codec.encode(_entryToJson(entry.value)),
      );
    }
  }

  TokenBalanceCacheEntry? _entryForKey(String key) {
    final rawValue = _registry.tokenBalancesBox.get(key);
    if (rawValue is! String) {
      return null;
    }
    try {
      return _entryFromJson(_codec.decode(rawValue));
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _entryToJson(TokenBalanceCacheEntry entry) {
    return {
      'rawBalance': entry.rawBalance,
      'formattedBalance': entry.formattedBalance,
      'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
      'expiresAt': entry.expiresAt.toUtc().toIso8601String(),
    };
  }

  TokenBalanceCacheEntry _entryFromJson(Map<String, Object?> json) {
    final rawBalance = json['rawBalance'];
    final formattedBalance = json['formattedBalance'];
    final updatedAt = json['updatedAt'];
    final expiresAt = json['expiresAt'];
    if (rawBalance is! String ||
        formattedBalance is! String ||
        updatedAt is! String ||
        expiresAt is! String) {
      throw const FormatException('Stored token balance is incomplete');
    }
    return TokenBalanceCacheEntry(
      rawBalance: rawBalance,
      formattedBalance: formattedBalance,
      updatedAt: DateTime.parse(updatedAt).toUtc(),
      expiresAt: DateTime.parse(expiresAt).toUtc(),
    );
  }
}
