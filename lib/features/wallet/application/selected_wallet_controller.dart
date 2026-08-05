import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

final selectedWalletStoreProvider = Provider<SelectedWalletStore>(
  (ref) => InMemorySelectedWalletStore(),
);

final selectedWalletIdProvider =
    NotifierProvider<SelectedWalletController, String?>(
  SelectedWalletController.new,
);

abstract interface class SelectedWalletStore {
  String? readSelectedWalletId();

  Future<void> writeSelectedWalletId(String? walletId);
}

final class InMemorySelectedWalletStore implements SelectedWalletStore {
  String? _walletId;

  @override
  String? readSelectedWalletId() {
    return _walletId;
  }

  @override
  Future<void> writeSelectedWalletId(String? walletId) async {
    _walletId = walletId;
  }
}

final class HiveSelectedWalletStore implements SelectedWalletStore {
  HiveSelectedWalletStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  String? readSelectedWalletId() {
    final walletId = _registry.settingsBox.get(StorageKeys.selectedWalletId);
    if (walletId is String && walletId.isNotEmpty) {
      return walletId;
    }
    return null;
  }

  @override
  Future<void> writeSelectedWalletId(String? walletId) {
    if (walletId == null || walletId.isEmpty) {
      return _registry.settingsBox.delete(StorageKeys.selectedWalletId);
    }
    return _registry.settingsBox.put(StorageKeys.selectedWalletId, walletId);
  }
}

final class SelectedWalletController extends Notifier<String?> {
  @override
  String? build() {
    return ref.read(selectedWalletStoreProvider).readSelectedWalletId();
  }

  Future<void> select(String walletId) async {
    state = walletId;
    await ref.read(selectedWalletStoreProvider).writeSelectedWalletId(walletId);
  }

  Future<void> clear() async {
    state = null;
    await ref.read(selectedWalletStoreProvider).writeSelectedWalletId(null);
  }
}
