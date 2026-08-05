import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/settings/application/wallet_auto_lock_setting.dart';

void main() {
  test('defaults to five minutes', () async {
    final store = InMemoryWalletAutoLockSettingStore();
    final container = ProviderContainer(
      overrides: [
        walletAutoLockSettingStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(walletAutoLockSettingProvider.future),
      WalletAutoLockDuration.fiveMinutes,
    );
  });

  test('persists the selected auto-lock duration', () async {
    final store = InMemoryWalletAutoLockSettingStore();
    final container = ProviderContainer(
      overrides: [
        walletAutoLockSettingStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    await container.read(walletAutoLockSettingProvider.future);

    await container
        .read(walletAutoLockSettingProvider.notifier)
        .setDuration(WalletAutoLockDuration.oneHour);

    expect(await store.readDuration(), WalletAutoLockDuration.oneHour);
    expect(
      container.read(walletAutoLockSettingProvider).value,
      WalletAutoLockDuration.oneHour,
    );
  });
}
