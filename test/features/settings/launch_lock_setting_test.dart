import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('LaunchLockSettingController', () {
    ProviderContainer buildContainer(LaunchLockSettingStore store) {
      final container = ProviderContainer(
        overrides: [launchLockSettingStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('requires password on launch by default', () async {
      final container = buildContainer(InMemoryLaunchLockSettingStore());

      expect(await container.read(launchLockSettingProvider.future), isTrue);
    });

    test('persists disabled and enabled values through the store', () async {
      final store = InMemoryLaunchLockSettingStore();
      final container = buildContainer(store);

      await container
          .read(launchLockSettingProvider.notifier)
          .setRequirePasswordOnLaunch(false);

      final restartedContainer = buildContainer(store);
      expect(
        await restartedContainer.read(launchLockSettingProvider.future),
        isFalse,
      );

      await restartedContainer
          .read(launchLockSettingProvider.notifier)
          .setRequirePasswordOnLaunch(true);

      final secondRestartContainer = buildContainer(store);
      expect(
        await secondRestartContainer.read(launchLockSettingProvider.future),
        isTrue,
      );
    });

    test('Hive store persists disabled launch lock after reopening storage',
        () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_launch_lock_test_',
      );
      addTearDown(() async {
        await Hive.close();
        if (tempDirectory.existsSync()) {
          await tempDirectory.delete(recursive: true);
        }
      });
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final store = HiveLaunchLockSettingStore(registry: registry);

      await store.saveRequirePasswordOnLaunch(false);
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveLaunchLockSettingStore(
        registry: reopenedRegistry,
      );

      expect(await reopenedStore.readRequirePasswordOnLaunch(), isFalse);
    });
  });
}
