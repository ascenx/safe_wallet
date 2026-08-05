import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/settings/application/theme_color_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_mode_setting.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/design/app_brand_colors.dart';

void main() {
  testWidgets('Safe Wallet app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_EmptyWalletRepository()),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('创建钱包'), findsOneWidget);
    expect(find.text('导入钱包'), findsOneWidget);
  });

  testWidgets('theme color changes update the app theme immediately', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_EmptyWalletRepository()),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SafeWalletApp)),
      listen: false,
    );
    await container
        .read(themeColorSettingProvider.notifier)
        .setThemeColor(AppThemeColor.green);
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme?.colorScheme.primary,
      AppThemeColor.green.palette.primary,
    );
  });

  testWidgets('theme mode defaults to light and updates immediately', (
    WidgetTester tester,
  ) async {
    final store = InMemoryThemeModeSettingStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_EmptyWalletRepository()),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
          themeModeSettingStoreProvider.overrideWithValue(store),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme?.brightness, Brightness.dark);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SafeWalletApp)),
      listen: false,
    );
    await container
        .read(themeModeSettingProvider.notifier)
        .setThemeMode(AppThemeMode.dark);
    await tester.pumpAndSettle();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(await store.readThemeModeId(), AppThemeMode.dark.name);
  });

  testWidgets('onboarding entry keeps copy at top and actions at bottom', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_EmptyWalletRepository()),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.wallet), findsNothing);

    final titleTop = tester.getTopLeft(find.text('安全地开始使用钱包')).dy;
    expect(titleTop, lessThan(80));

    final importButtonBottom =
        tester.getBottomLeft(find.widgetWithText(OutlinedButton, '导入钱包')).dy;
    expect(importButtonBottom, greaterThan(760));
  });
}

final class _EmptyWalletRepository implements WalletRepository {
  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => const [];

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }
}
