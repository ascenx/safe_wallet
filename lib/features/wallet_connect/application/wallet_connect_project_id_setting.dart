import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

enum WalletConnectProjectIdSource {
  custom,
  build,
  missing,
}

final class WalletConnectProjectIdSettingState {
  const WalletConnectProjectIdSettingState({
    required this.buildProjectId,
    required this.customProjectId,
    required this.effectiveProjectId,
    required this.source,
  });

  final String buildProjectId;
  final String? customProjectId;
  final String effectiveProjectId;
  final WalletConnectProjectIdSource source;
}

abstract interface class WalletConnectProjectIdStore {
  String? readCustomProjectId();

  Future<void> saveCustomProjectId(String value);

  Future<void> deleteCustomProjectId();
}

final class InMemoryWalletConnectProjectIdStore
    implements WalletConnectProjectIdStore {
  InMemoryWalletConnectProjectIdStore({String? projectId})
      : _projectId = projectId;

  String? _projectId;

  @override
  String? readCustomProjectId() => _projectId;

  @override
  Future<void> saveCustomProjectId(String value) async {
    _projectId = value;
  }

  @override
  Future<void> deleteCustomProjectId() async {
    _projectId = null;
  }
}

final class HiveWalletConnectProjectIdStore
    implements WalletConnectProjectIdStore {
  HiveWalletConnectProjectIdStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  String? readCustomProjectId() {
    final value = _registry.settingsBox.get(
      StorageKeys.walletConnectProjectId,
    );
    return value is String ? value : null;
  }

  @override
  Future<void> saveCustomProjectId(String value) {
    return _registry.settingsBox.put(
      StorageKeys.walletConnectProjectId,
      value,
    );
  }

  @override
  Future<void> deleteCustomProjectId() {
    return _registry.settingsBox.delete(StorageKeys.walletConnectProjectId);
  }
}

final walletConnectBuildProjectIdProvider = Provider<String>((ref) {
  return const String.fromEnvironment('REOWN_PROJECT_ID');
});

final walletConnectProjectIdStoreProvider =
    Provider<WalletConnectProjectIdStore>(
  (ref) => InMemoryWalletConnectProjectIdStore(),
);

final walletConnectProjectIdSettingProvider = NotifierProvider<
    WalletConnectProjectIdSettingController,
    WalletConnectProjectIdSettingState>(
  WalletConnectProjectIdSettingController.new,
);

final walletConnectProjectIdProvider = Provider<String>((ref) {
  return ref.watch(walletConnectProjectIdSettingProvider).effectiveProjectId;
});

final class WalletConnectProjectIdSettingController
    extends Notifier<WalletConnectProjectIdSettingState> {
  @override
  WalletConnectProjectIdSettingState build() {
    final buildProjectId = ref.read(walletConnectBuildProjectIdProvider).trim();
    final storedProjectId = ref
        .read(walletConnectProjectIdStoreProvider)
        .readCustomProjectId()
        ?.trim();
    final customProjectId =
        storedProjectId != null && isValidReownProjectId(storedProjectId)
            ? storedProjectId
            : null;
    return _createState(
      buildProjectId: buildProjectId,
      customProjectId: customProjectId,
    );
  }

  Future<bool> setCustomProjectId(String value) async {
    final projectId = value.trim();
    if (!isValidReownProjectId(projectId)) {
      return false;
    }
    await ref
        .read(walletConnectProjectIdStoreProvider)
        .saveCustomProjectId(projectId);
    state = _createState(
      buildProjectId: state.buildProjectId,
      customProjectId: projectId,
    );
    return true;
  }

  Future<void> deleteCustomProjectId() async {
    await ref.read(walletConnectProjectIdStoreProvider).deleteCustomProjectId();
    state = _createState(
      buildProjectId: state.buildProjectId,
      customProjectId: null,
    );
  }
}

WalletConnectProjectIdSettingState _createState({
  required String buildProjectId,
  required String? customProjectId,
}) {
  final effectiveProjectId = customProjectId ?? buildProjectId;
  final source = customProjectId != null
      ? WalletConnectProjectIdSource.custom
      : buildProjectId.isNotEmpty
          ? WalletConnectProjectIdSource.build
          : WalletConnectProjectIdSource.missing;
  return WalletConnectProjectIdSettingState(
    buildProjectId: buildProjectId,
    customProjectId: customProjectId,
    effectiveProjectId: effectiveProjectId,
    source: source,
  );
}

bool isValidReownProjectId(String value) {
  return RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value.trim());
}
