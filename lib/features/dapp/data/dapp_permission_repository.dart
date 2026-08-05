import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dapp_permission.dart';

final dappPermissionRepositoryProvider = Provider<DappPermissionRepository>(
  (ref) => InMemoryDappPermissionRepository(),
);

abstract interface class DappPermissionRepository {
  Future<DappPermission?> permissionFor({
    required String domain,
    required String walletId,
    required String chainId,
  });

  Future<List<DappPermission>> listForDomain(String domain);

  Future<List<DappPermission>> listAll();

  Future<void> save(DappPermission permission);

  Future<void> revoke(String permissionId);

  Future<void> clearAll();

  Future<void> clearForWallet(String walletId);

  Future<DappPermission?> touch({
    required String domain,
    required String walletId,
    required String chainId,
    required DateTime lastUsedAt,
  });
}

final class InMemoryDappPermissionRepository
    implements DappPermissionRepository {
  final Map<String, DappPermission> _permissions = {};

  @override
  Future<DappPermission?> permissionFor({
    required String domain,
    required String walletId,
    required String chainId,
  }) async {
    return _permissions[dappPermissionId(
      domain: domain,
      walletId: walletId,
      chainId: chainId,
    )];
  }

  @override
  Future<List<DappPermission>> listForDomain(String domain) async {
    final normalizedDomain = normalizeDappDomain(domain);
    final permissions =
        _permissions.values
            .where((permission) => permission.domain == normalizedDomain)
            .toList()
          ..sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(permissions);
  }

  @override
  Future<List<DappPermission>> listAll() async {
    final permissions = _permissions.values.toList()
      ..sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return List.unmodifiable(permissions);
  }

  @override
  Future<void> save(DappPermission permission) async {
    _permissions[permission.id] = permission;
  }

  @override
  Future<void> revoke(String permissionId) async {
    _permissions.remove(permissionId);
  }

  @override
  Future<void> clearAll() async {
    _permissions.clear();
  }

  @override
  Future<void> clearForWallet(String walletId) async {
    _permissions.removeWhere(
      (_, permission) => permission.walletId == walletId,
    );
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
}

String dappPermissionId({
  required String domain,
  required String walletId,
  required String chainId,
}) {
  return '${normalizeDappDomain(domain)}|$walletId|$chainId';
}

String normalizeDappDomain(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final defaultPort = scheme == 'https' ? 443 : 80;
    final port = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
    return '$scheme://$host$port';
  }
  final hostOnly = trimmed
      .split('/')
      .first
      .replaceFirst(RegExp(r'^https?:\/\/'), '')
      .toLowerCase();
  final assumedHttps = Uri.tryParse('https://$hostOnly');
  if (assumedHttps != null &&
      assumedHttps.host.isNotEmpty &&
      assumedHttps.userInfo.isEmpty) {
    final port = assumedHttps.hasPort && assumedHttps.port != 443
        ? ':${assumedHttps.port}'
        : '';
    return 'https://${assumedHttps.host.toLowerCase()}$port';
  }
  return hostOnly;
}
