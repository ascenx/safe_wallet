import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_project_id_setting.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  const buildProjectId = '11111111111111111111111111111111';
  const customProjectId = '22222222222222222222222222222222';
  const replacementProjectId = '33333333333333333333333333333333';

  ProviderContainer buildContainer(WalletConnectProjectIdStore store) {
    final container = ProviderContainer(
      overrides: [
        walletConnectBuildProjectIdProvider.overrideWithValue(buildProjectId),
        walletConnectProjectIdStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('custom Project ID overrides build configuration', () {
    final container = buildContainer(
      InMemoryWalletConnectProjectIdStore(projectId: customProjectId),
    );

    final setting = container.read(walletConnectProjectIdSettingProvider);

    expect(setting.effectiveProjectId, customProjectId);
    expect(setting.source, WalletConnectProjectIdSource.custom);
    expect(container.read(walletConnectProjectIdProvider), customProjectId);
  });

  test('replacing and deleting custom Project ID updates the effective value',
      () async {
    final store = InMemoryWalletConnectProjectIdStore(
      projectId: customProjectId,
    );
    final container = buildContainer(store);
    final controller = container.read(
      walletConnectProjectIdSettingProvider.notifier,
    );

    expect(await controller.setCustomProjectId(replacementProjectId), isTrue);
    expect(
      container.read(walletConnectProjectIdSettingProvider).effectiveProjectId,
      replacementProjectId,
    );
    await controller.deleteCustomProjectId();

    final setting = container.read(walletConnectProjectIdSettingProvider);
    expect(setting.effectiveProjectId, buildProjectId);
    expect(setting.source, WalletConnectProjectIdSource.build);
    expect(store.readCustomProjectId(), isNull);
  });

  test('rejects malformed Project IDs without changing persisted value',
      () async {
    final store = InMemoryWalletConnectProjectIdStore();
    final container = buildContainer(store);

    final saved = await container
        .read(walletConnectProjectIdSettingProvider.notifier)
        .setCustomProjectId('not-a-project-id');

    expect(saved, isFalse);
    expect(store.readCustomProjectId(), isNull);
    expect(isValidReownProjectId(buildProjectId), isTrue);
    expect(isValidReownProjectId('f' * 31), isFalse);
  });

  test('Hive store keeps custom Project ID after reopening storage', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'safe_wallet_wallet_connect_project_id_test_',
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
    final store = HiveWalletConnectProjectIdStore(registry: registry);

    await store.saveCustomProjectId(customProjectId);
    await Hive.close();

    final reopenedRegistry = await StorageInitializer(
      path: tempDirectory.path,
    ).initialize();
    final reopenedStore = HiveWalletConnectProjectIdStore(
      registry: reopenedRegistry,
    );

    expect(reopenedStore.readCustomProjectId(), customProjectId);
    await reopenedStore.deleteCustomProjectId();
    expect(reopenedStore.readCustomProjectId(), isNull);
  });
}
