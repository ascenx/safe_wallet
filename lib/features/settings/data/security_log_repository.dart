import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../domain/security_log_entry.dart';

final securityLogRepositoryProvider = Provider<SecurityLogRepository>((ref) {
  return InMemorySecurityLogRepository();
});

abstract interface class SecurityLogRepository {
  Future<void> record(
    SecurityLogEventType type, {
    DateTime? occurredAt,
    String? walletName,
    String? chainName,
    String? assetSymbol,
    String? amount,
    String? address,
  });

  Future<List<SecurityLogEntry>> listEntries();
}

final class HiveSecurityLogRepository implements SecurityLogRepository {
  HiveSecurityLogRepository({
    required HiveBoxRegistry registry,
    this.maxEntries = 200,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;
  final int maxEntries;

  @override
  Future<void> record(
    SecurityLogEventType type, {
    DateTime? occurredAt,
    String? walletName,
    String? chainName,
    String? assetSymbol,
    String? amount,
    String? address,
  }) async {
    final normalizedWalletName = _normalizedLabel(walletName);
    final normalizedChainName = _normalizedLabel(chainName);
    final normalizedAssetSymbol = _normalizedLabel(assetSymbol);
    final normalizedAmount = _normalizedLabel(amount);
    final normalizedAddress = _normalizedLabel(address);
    await _registry.securityLogsBox.add(
      _codec.encode({
        'type': type.name,
        'occurredAt': (occurredAt ?? DateTime.now().toUtc()).toIso8601String(),
        'walletName': ?normalizedWalletName,
        'chainName': ?normalizedChainName,
        'assetSymbol': ?normalizedAssetSymbol,
        'amount': ?normalizedAmount,
        'address': ?normalizedAddress,
      }),
    );
    final overflow = _registry.securityLogsBox.length - maxEntries;
    if (overflow > 0) {
      await _registry.securityLogsBox.deleteAll(
        _registry.securityLogsBox.keys.take(overflow),
      );
    }
  }

  @override
  Future<List<SecurityLogEntry>> listEntries() async {
    final entries =
        _registry.securityLogsBox.values
            .whereType<String>()
            .map(_decodeEntry)
            .whereType<SecurityLogEntry>()
            .toList()
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return List.unmodifiable(entries);
  }

  SecurityLogEntry? _decodeEntry(String value) {
    return _codec.tryDecode(value, _entryFromJson);
  }

  SecurityLogEntry? _entryFromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final occurredAt = json['occurredAt'];
    if (typeName is! String || occurredAt is! String) {
      return null;
    }
    final type = SecurityLogEventType.values
        .where((candidate) => candidate.name == typeName)
        .firstOrNull;
    final parsedTime = DateTime.tryParse(occurredAt);
    if (type == null || parsedTime == null) {
      return null;
    }
    return SecurityLogEntry(
      type: type,
      occurredAt: parsedTime.toUtc(),
      walletName: _normalizedLabel(
        json['walletName'] is String ? json['walletName'] as String : null,
      ),
      chainName: _normalizedLabel(
        json['chainName'] is String ? json['chainName'] as String : null,
      ),
      assetSymbol: _normalizedLabel(
        json['assetSymbol'] is String ? json['assetSymbol'] as String : null,
      ),
      amount: _normalizedLabel(
        json['amount'] is String ? json['amount'] as String : null,
      ),
      address: _normalizedLabel(
        json['address'] is String ? json['address'] as String : null,
      ),
    );
  }
}

final class InMemorySecurityLogRepository implements SecurityLogRepository {
  final List<SecurityLogEntry> _entries = [];

  @override
  Future<void> record(
    SecurityLogEventType type, {
    DateTime? occurredAt,
    String? walletName,
    String? chainName,
    String? assetSymbol,
    String? amount,
    String? address,
  }) async {
    _entries.add(
      SecurityLogEntry(
        type: type,
        occurredAt: occurredAt ?? DateTime.now().toUtc(),
        walletName: _normalizedLabel(walletName),
        chainName: _normalizedLabel(chainName),
        assetSymbol: _normalizedLabel(assetSymbol),
        amount: _normalizedLabel(amount),
        address: _normalizedLabel(address),
      ),
    );
  }

  @override
  Future<List<SecurityLogEntry>> listEntries() async {
    final entries = [..._entries]
      ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return List.unmodifiable(entries);
  }
}

String? _normalizedLabel(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final runes = normalized.runes;
  return runes.length <= 120
      ? normalized
      : String.fromCharCodes(runes.take(120));
}
