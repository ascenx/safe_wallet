import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../domain/dapp_permission.dart';
import 'dapp_permission_repository.dart';

final class HiveDappPermissionRepository implements DappPermissionRepository {
  HiveDappPermissionRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<DappPermission?> permissionFor({
    required String domain,
    required String walletId,
    required String chainId,
  }) async {
    final rawValue = _registry.dappPermissionsBox.get(
      dappPermissionId(domain: domain, walletId: walletId, chainId: chainId),
    );
    if (rawValue is! String) {
      return null;
    }
    return _codec.tryDecode(rawValue, _permissionFromJson);
  }

  @override
  Future<List<DappPermission>> listForDomain(String domain) async {
    final normalizedDomain = normalizeDappDomain(domain);
    final permissions =
        _registry.dappPermissionsBox.values
            .whereType<String>()
            .map((value) => _codec.tryDecode(value, _permissionFromJson))
            .whereType<DappPermission>()
            .where((permission) => permission.domain == normalizedDomain)
            .toList()
          ..sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(permissions);
  }

  @override
  Future<List<DappPermission>> listAll() async {
    final permissions =
        _registry.dappPermissionsBox.values
            .whereType<String>()
            .map((value) => _codec.tryDecode(value, _permissionFromJson))
            .whereType<DappPermission>()
            .toList()
          ..sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(permissions);
  }

  @override
  Future<void> save(DappPermission permission) async {
    await _registry.dappPermissionsBox.put(
      permission.id,
      _codec.encode(_permissionToJson(permission)),
    );
  }

  @override
  Future<void> revoke(String permissionId) async {
    await _registry.dappPermissionsBox.delete(permissionId);
  }

  @override
  Future<void> clearAll() async {
    await _registry.dappPermissionsBox.clear();
  }

  @override
  Future<void> clearForWallet(String walletId) async {
    final keys = <dynamic>[];
    for (final key in _registry.dappPermissionsBox.keys) {
      final rawValue = _registry.dappPermissionsBox.get(key);
      if (rawValue is! String) {
        continue;
      }
      final permission = _codec.tryDecode(rawValue, _permissionFromJson);
      if (permission == null) {
        continue;
      }
      if (permission.walletId == walletId) {
        keys.add(key);
      }
    }
    await _registry.dappPermissionsBox.deleteAll(keys);
  }

  @override
  Future<DappPermission?> touch({
    required String domain,
    required String walletId,
    required String chainId,
    required DateTime lastUsedAt,
  }) async {
    final existing = await permissionFor(
      domain: domain,
      walletId: walletId,
      chainId: chainId,
    );
    if (existing == null) {
      return null;
    }
    final next = DappPermission(
      id: existing.id,
      domain: existing.domain,
      walletId: existing.walletId,
      chainId: existing.chainId,
      address: existing.address,
      grantedAt: existing.grantedAt,
      lastUsedAt: lastUsedAt,
      expiresAt: existing.expiresAt,
    );
    await save(next);
    return next;
  }

  Map<String, Object?> _permissionToJson(DappPermission permission) {
    return {
      'id': permission.id,
      'domain': permission.domain,
      'walletId': permission.walletId,
      'chainId': permission.chainId,
      'address': permission.address,
      'grantedAt': permission.grantedAt.toIso8601String(),
      'lastUsedAt': permission.lastUsedAt.toIso8601String(),
      if (permission.expiresAt != null)
        'expiresAt': permission.expiresAt!.toIso8601String(),
    };
  }

  DappPermission _permissionFromJson(Map<String, Object?> json) {
    return DappPermission(
      id: json['id'] as String,
      domain: json['domain'] as String,
      walletId: json['walletId'] as String,
      chainId: json['chainId'] as String,
      address: json['address'] as String,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      expiresAt: json['expiresAt'] is String
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}
