import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dapp_permission_repository.dart';
import '../domain/dapp_permission.dart';

final dappPermissionControllerProvider =
    AsyncNotifierProvider<DappPermissionController, List<DappPermission>>(
      DappPermissionController.new,
    );

enum DappPermissionDecision { approved, rejected }

final class DappPermissionController
    extends AsyncNotifier<List<DappPermission>> {
  static const persistentPermissionLifetime = Duration(days: 30);

  final Map<String, DappPermission> _sessionPermissions = {};

  @override
  Future<List<DappPermission>> build() async {
    return ref.read(dappPermissionRepositoryProvider).listAll();
  }

  Future<DappPermission> approve({
    required String domain,
    required String walletId,
    required String chainId,
    required String address,
    DateTime? now,
    bool persistent = false,
  }) async {
    final timestamp = now ?? DateTime.now().toUtc();
    final normalizedDomain = normalizeDappDomain(domain);
    final permission = DappPermission(
      id: dappPermissionId(
        domain: normalizedDomain,
        walletId: walletId,
        chainId: chainId,
      ),
      domain: normalizedDomain,
      walletId: walletId,
      chainId: chainId,
      address: address,
      grantedAt: timestamp,
      lastUsedAt: timestamp,
      expiresAt: persistent
          ? timestamp.add(persistentPermissionLifetime)
          : null,
    );
    if (persistent) {
      _sessionPermissions.remove(permission.id);
      await ref.read(dappPermissionRepositoryProvider).save(permission);
    } else {
      _sessionPermissions[permission.id] = permission;
    }
    await _reload();
    return permission;
  }

  Future<DappPermissionDecision> reject({
    required String domain,
    required String walletId,
    required String chainId,
  }) async {
    return DappPermissionDecision.rejected;
  }

  Future<DappPermission?> permissionFor({
    required String domain,
    required String walletId,
    required String chainId,
    DateTime? now,
  }) async {
    final id = dappPermissionId(
      domain: domain,
      walletId: walletId,
      chainId: chainId,
    );
    final sessionPermission = _sessionPermissions[id];
    if (sessionPermission != null) {
      return sessionPermission;
    }
    final persistentPermission = await ref
        .read(dappPermissionRepositoryProvider)
        .permissionFor(domain: domain, walletId: walletId, chainId: chainId);
    if (persistentPermission?.isExpiredAt(now ?? DateTime.now().toUtc()) ??
        false) {
      await ref.read(dappPermissionRepositoryProvider).revoke(id);
      await _reload();
      return null;
    }
    return persistentPermission;
  }

  Future<void> clearAll() async {
    state = const AsyncLoading();
    _sessionPermissions.clear();
    await ref.read(dappPermissionRepositoryProvider).clearAll();
    state = const AsyncData([]);
  }

  Future<void> clearForWallet(String walletId) async {
    state = const AsyncLoading();
    _sessionPermissions.removeWhere(
      (_, permission) => permission.walletId == walletId,
    );
    await ref.read(dappPermissionRepositoryProvider).clearForWallet(walletId);
    await _reload();
  }

  Future<void> revoke(String permissionId) async {
    state = const AsyncLoading();
    _sessionPermissions.remove(permissionId);
    await ref.read(dappPermissionRepositoryProvider).revoke(permissionId);
    await _reload();
  }

  Future<DappPermission?> touch({
    required String domain,
    required String walletId,
    required String chainId,
    DateTime? now,
  }) async {
    final id = dappPermissionId(
      domain: domain,
      walletId: walletId,
      chainId: chainId,
    );
    final sessionPermission = _sessionPermissions[id];
    if (sessionPermission != null) {
      final next = DappPermission(
        id: sessionPermission.id,
        domain: sessionPermission.domain,
        walletId: sessionPermission.walletId,
        chainId: sessionPermission.chainId,
        address: sessionPermission.address,
        grantedAt: sessionPermission.grantedAt,
        lastUsedAt: now ?? DateTime.now().toUtc(),
      );
      _sessionPermissions[id] = next;
      await _reload();
      return next;
    }
    final permission = await ref
        .read(dappPermissionRepositoryProvider)
        .touch(
          domain: domain,
          walletId: walletId,
          chainId: chainId,
          lastUsedAt: now ?? DateTime.now().toUtc(),
        );
    if (permission != null) {
      await _reload();
    }
    return permission;
  }

  Future<void> _reload() async {
    final persistent = await ref
        .read(dappPermissionRepositoryProvider)
        .listAll();
    state = AsyncData([
      ..._sessionPermissions.values,
      ...persistent.where(
        (permission) => !_sessionPermissions.containsKey(permission.id),
      ),
    ]);
  }
}
