import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';
import '../../wallet/domain/wallet_account.dart';

final walletDeletionJournalProvider = Provider<WalletDeletionJournal>(
  (ref) => InMemoryWalletDeletionJournal(),
);

final class PendingWalletDeletion {
  const PendingWalletDeletion({required this.account});

  final WalletAccount account;
}

abstract interface class WalletDeletionJournal {
  Future<PendingWalletDeletion?> read();

  Future<void> write(PendingWalletDeletion deletion);

  Future<void> clear();
}

final class InMemoryWalletDeletionJournal implements WalletDeletionJournal {
  PendingWalletDeletion? _pending;

  @override
  Future<PendingWalletDeletion?> read() async => _pending;

  @override
  Future<void> write(PendingWalletDeletion deletion) async {
    _pending = deletion;
  }

  @override
  Future<void> clear() async {
    _pending = null;
  }
}

final class HiveWalletDeletionJournal implements WalletDeletionJournal {
  HiveWalletDeletionJournal({required HiveBoxRegistry registry})
    : _registry = registry;

  static const _version = 1;

  final HiveBoxRegistry _registry;

  @override
  Future<PendingWalletDeletion?> read() async {
    final raw = _registry.settingsBox.get(
      StorageKeys.pendingWalletDeletionCleanup,
    );
    if (raw == null) {
      return null;
    }
    final account = _decodeAccount(raw);
    if (account == null) {
      await clear();
      return null;
    }
    return PendingWalletDeletion(account: account);
  }

  @override
  Future<void> write(PendingWalletDeletion deletion) {
    final account = deletion.account;
    return _registry.settingsBox.put(StorageKeys.pendingWalletDeletionCleanup, {
      'version': _version,
      'account': {
        'id': account.id,
        'name': account.name,
        'evmAddress': account.evmAddress,
        'tronAddress': account.tronAddress,
        'solanaAddress': account.solanaAddress,
        'btcAddress': account.btcAddress,
        'suiAddress': account.suiAddress,
        'suiPublicKey': account.suiPublicKey,
        'source': account.source.name,
        'createdAt': account.createdAt.toUtc().toIso8601String(),
        'updatedAt': account.updatedAt.toUtc().toIso8601String(),
      },
    });
  }

  @override
  Future<void> clear() =>
      _registry.settingsBox.delete(StorageKeys.pendingWalletDeletionCleanup);

  WalletAccount? _decodeAccount(Object? raw) {
    if (raw is! Map || raw['version'] != _version) {
      return null;
    }
    final account = raw['account'];
    if (account is! Map) {
      return null;
    }
    final id = account['id'];
    final name = account['name'];
    final evmAddress = account['evmAddress'];
    final tronAddress = account['tronAddress'];
    final solanaAddress = account['solanaAddress'];
    final btcAddress = account['btcAddress'];
    final suiAddress = account['suiAddress'];
    final suiPublicKey = account['suiPublicKey'];
    final source = account['source'];
    final createdAt = DateTime.tryParse(account['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(account['updatedAt']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        evmAddress is! String ||
        tronAddress is! String ||
        solanaAddress is! String ||
        btcAddress is! String ||
        suiAddress is! String ||
        suiPublicKey is! String ||
        source is! String ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    final accountSource = WalletAccountSource.values
        .where((value) => value.name == source)
        .firstOrNull;
    if (accountSource == null) {
      return null;
    }
    return WalletAccount(
      id: id,
      name: name,
      evmAddress: evmAddress,
      tronAddress: tronAddress,
      solanaAddress: solanaAddress,
      btcAddress: btcAddress,
      suiAddress: suiAddress,
      suiPublicKey: suiPublicKey,
      source: accountSource,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
