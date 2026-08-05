import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

enum WalletAutoLockDuration {
  immediately('immediately', Duration.zero),
  oneMinute('oneMinute', Duration(minutes: 1)),
  fiveMinutes('fiveMinutes', Duration(minutes: 5)),
  fifteenMinutes('fifteenMinutes', Duration(minutes: 15)),
  oneHour('oneHour', Duration(hours: 1));

  const WalletAutoLockDuration(this.id, this.duration);

  final String id;
  final Duration duration;

  static WalletAutoLockDuration fromId(Object? id) {
    for (final value in values) {
      if (value.id == id) {
        return value;
      }
    }
    return fiveMinutes;
  }
}

final walletAutoLockSettingStoreProvider =
    Provider<WalletAutoLockSettingStore>(
  (ref) => InMemoryWalletAutoLockSettingStore(),
);

final walletAutoLockSettingProvider =
    AsyncNotifierProvider<
      WalletAutoLockSettingController,
      WalletAutoLockDuration
    >(WalletAutoLockSettingController.new);

abstract interface class WalletAutoLockSettingStore {
  Future<WalletAutoLockDuration> readDuration();

  Future<void> saveDuration(WalletAutoLockDuration value);
}

final class InMemoryWalletAutoLockSettingStore
    implements WalletAutoLockSettingStore {
  InMemoryWalletAutoLockSettingStore({WalletAutoLockDuration? duration})
      : _duration = duration;

  WalletAutoLockDuration? _duration;

  @override
  Future<WalletAutoLockDuration> readDuration() async {
    return _duration ?? WalletAutoLockDuration.fiveMinutes;
  }

  @override
  Future<void> saveDuration(WalletAutoLockDuration value) async {
    _duration = value;
  }
}

final class HiveWalletAutoLockSettingStore
    implements WalletAutoLockSettingStore {
  HiveWalletAutoLockSettingStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<WalletAutoLockDuration> readDuration() async {
    return WalletAutoLockDuration.fromId(
      _registry.settingsBox.get(StorageKeys.walletAutoLockDuration),
    );
  }

  @override
  Future<void> saveDuration(WalletAutoLockDuration value) {
    return _registry.settingsBox.put(
      StorageKeys.walletAutoLockDuration,
      value.id,
    );
  }
}

final class WalletAutoLockSettingController
    extends AsyncNotifier<WalletAutoLockDuration> {
  @override
  Future<WalletAutoLockDuration> build() {
    return ref.read(walletAutoLockSettingStoreProvider).readDuration();
  }

  Future<void> setDuration(WalletAutoLockDuration value) async {
    state = AsyncData(value);
    await ref.read(walletAutoLockSettingStoreProvider).saveDuration(value);
  }
}
