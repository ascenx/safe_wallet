import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('SelectedWalletController', () {
    test('loads the persisted selected wallet id on rebuild', () async {
      final store = InMemorySelectedWalletStore();
      final firstContainer = ProviderContainer(
        overrides: [selectedWalletStoreProvider.overrideWithValue(store)],
      );
      addTearDown(firstContainer.dispose);

      await firstContainer
          .read(selectedWalletIdProvider.notifier)
          .select('wallet-2');

      final secondContainer = ProviderContainer(
        overrides: [selectedWalletStoreProvider.overrideWithValue(store)],
      );
      addTearDown(secondContainer.dispose);

      expect(secondContainer.read(selectedWalletIdProvider), 'wallet-2');
    });

    test('clears the persisted selected wallet id', () async {
      final store = InMemorySelectedWalletStore();
      final container = ProviderContainer(
        overrides: [selectedWalletStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container
          .read(selectedWalletIdProvider.notifier)
          .select('wallet-2');
      await container.read(selectedWalletIdProvider.notifier).clear();

      final restartedContainer = ProviderContainer(
        overrides: [selectedWalletStoreProvider.overrideWithValue(store)],
      );
      addTearDown(restartedContainer.dispose);

      expect(restartedContainer.read(selectedWalletIdProvider), isNull);
    });

    test('Hive store persists the selected wallet id after reopening storage',
        () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_selected_wallet_test_',
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
      final store = HiveSelectedWalletStore(registry: registry);

      await store.writeSelectedWalletId('wallet-2');
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveSelectedWalletStore(registry: reopenedRegistry);

      expect(reopenedStore.readSelectedWalletId(), 'wallet-2');
    });
  });
}
