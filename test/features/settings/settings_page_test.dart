import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/dapp/domain/dapp_permission.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/settings/application/app_version_provider.dart';
import 'package:safe_wallet/features/settings/application/background_privacy_shield_setting.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_color_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_mode_setting.dart';
import 'package:safe_wallet/features/settings/application/wallet_auto_lock_setting.dart';
import 'package:safe_wallet/features/settings/presentation/language_settings_page.dart';
import 'package:safe_wallet/features/settings/presentation/preferences_settings_page.dart';
import 'package:safe_wallet/features/settings/presentation/security_settings_page.dart';
import 'package:safe_wallet/features/settings/presentation/settings_page.dart';
import 'package:safe_wallet/features/settings/presentation/theme_color_settings_page.dart';
import 'package:safe_wallet/features/staking/presentation/tron_staking_page.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_brand_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/widgets/app_action_sheet.dart';
import 'package:safe_wallet/shared/widgets/app_section_card.dart';

void main() {
  group('Settings', () {
    testWidgets('settings entries are visible', (tester) async {
      await tester.pumpWidget(_settingsAppWithProfile());
      await tester.pumpAndSettle();

      expect(find.text('钱包管理'), findsOneWidget);
      expect(find.text('网络管理'), findsOneWidget);
      expect(find.text('地址簿'), findsOneWidget);
      expect(find.text('高级'), findsOneWidget);
      expect(find.text('安全设置'), findsOneWidget);
      expect(find.text('偏好设置'), findsOneWidget);
      expect(find.text('多语言设置'), findsNothing);
      expect(find.text('主题颜色'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('关于'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(find.text('关于'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('高级')).dy,
        lessThan(tester.getTopLeft(find.text('安全设置')).dy),
      );
      expect(
        tester.getTopLeft(find.text('偏好设置')).dy,
        lessThan(tester.getTopLeft(find.text('关于')).dy),
      );
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();

      expect(find.text('Safe Wallet'), findsWidgets);
      expect(find.text('版本 9.8.7（Build 42）'), findsOneWidget);
    });

    testWidgets('advanced settings opens the EVM contract call tool', (
      tester,
    ) async {
      await tester.pumpWidget(_settingsAppWithProfile());
      await tester.pumpAndSettle();

      await tester.tap(find.text('高级'));
      await tester.pumpAndSettle();

      expect(find.text('合约调用'), findsOneWidget);

      await tester.tap(find.text('合约调用'));
      await tester.pumpAndSettle();

      expect(find.text('合约调用'), findsOneWidget);
      expect(find.byKey(const Key('evmContractNetworkPicker')), findsOneWidget);
      expect(find.text('合约地址'), findsOneWidget);
    });

    testWidgets('advanced settings exposes the TRX staking center', (
      tester,
    ) async {
      await tester.pumpWidget(_settingsAppWithProfile());
      await tester.pumpAndSettle();

      await tester.tap(find.text('高级'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advancedTronStaking')), findsOneWidget);
      expect(find.text('TRX 质押'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('advancedTronStaking')));
      await tester.tap(find.byKey(const Key('advancedTronStaking')));
      await tester.pumpAndSettle();

      expect(find.byType(TronStakingPage), findsOneWidget);
    });

    testWidgets('settings shows current wallet summary and chain', (
      tester,
    ) async {
      final account = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository([account]),
            ),
            chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
          ],
          child: _settingsMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
        listen: false,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await tester.pumpAndSettle();

      expect(find.text('Main Wallet'), findsOneWidget);
      expect(find.textContaining('0x9858...da94'), findsNothing);
      _expectHighlightedAddress(
        _addressSpanInText(tester, account.evmAddress),
        account.evmAddress,
      );
      expect(find.textContaining('Ethereum'), findsOneWidget);
    });

    testWidgets(
      'settings reloads wallets when an imported wallet is selected',
      (tester) async {
        final firstWallet = WalletAccount(
          id: 'wallet-1',
          name: 'Wallet 1',
          evmAddress: '0x1111111111111111111111111111111111111111',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        );
        final importedWallet = WalletAccount(
          id: 'wallet-2',
          name: 'Wallet 2',
          evmAddress: '0x2222222222222222222222222222222222222222',
          solanaAddress: 'So22222222222222222222222222222222222222222',
          source: WalletAccountSource.privateKey,
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        );
        final wallets = <WalletAccount>[firstWallet];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              walletRepositoryProvider.overrideWithValue(
                _FakeWalletRepository(wallets),
              ),
              chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
            ],
            child: _settingsMaterialApp(home: const SettingsPage()),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SettingsPage)),
          listen: false,
        );
        await container
            .read(selectedWalletIdProvider.notifier)
            .select(firstWallet.id);
        await tester.pumpAndSettle();

        wallets.add(importedWallet);
        await container
            .read(selectedWalletIdProvider.notifier)
            .select(importedWallet.id);
        await tester.pumpAndSettle();

        expect(find.text('Wallet 2'), findsOneWidget);
        expect(find.text('尚未创建钱包'), findsNothing);
        _expectHighlightedAddress(
          _addressSpanInText(tester, importedWallet.evmAddress),
          importedWallet.evmAddress,
        );
      },
    );

    testWidgets(
      'preferences page contains language currency and theme settings',
      (tester) async {
        await tester.pumpWidget(_settingsAppWithProfile());
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        await tester.tap(find.text('偏好设置'));
        await tester.pumpAndSettle();

        expect(find.byType(PreferencesSettingsPage), findsOneWidget);
        expect(find.text('多语言设置'), findsOneWidget);
        expect(find.text('跟随系统'), findsOneWidget);
        expect(
          tester.getCenter(find.text('跟随系统')).dx,
          greaterThan(tester.getCenter(find.text('多语言设置')).dx),
        );
        expect(find.text('货币'), findsOneWidget);
        expect(find.text('USD'), findsOneWidget);
        expect(find.text('主题颜色'), findsOneWidget);
        expect(find.text('靛蓝'), findsOneWidget);
      },
    );

    testWidgets('preferences fiat entry selects currency in an action sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _settingsMaterialApp(home: const PreferencesSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('货币'));
      await tester.pumpAndSettle();

      expect(find.text('美元 (USD)'), findsOneWidget);
      expect(find.text('人民币 (CNY)'), findsOneWidget);
      expect(find.text('欧元 (EUR)'), findsOneWidget);
      expect(find.text('日元 (JPY)'), findsOneWidget);

      await tester.tap(find.text('人民币 (CNY)'));
      await tester.pumpAndSettle();

      expect(find.text('CNY'), findsOneWidget);
    });

    testWidgets('preferences theme mode selects and persists dark mode', (
      tester,
    ) async {
      final store = InMemoryThemeModeSettingStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [themeModeSettingStoreProvider.overrideWithValue(store)],
          child: _settingsMaterialApp(home: const PreferencesSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('主题模式'), findsOneWidget);
      expect(find.text('亮色模式'), findsOneWidget);

      await tester.tap(find.text('主题模式'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppActionSheet<AppThemeMode>),
          matching: find.text('跟随系统'),
        ),
        findsOneWidget,
      );
      expect(find.text('亮色模式'), findsWidgets);
      expect(find.text('暗色模式'), findsOneWidget);

      await tester.tap(find.text('暗色模式'));
      await tester.pumpAndSettle();

      expect(await store.readThemeModeId(), AppThemeMode.dark.name);
      expect(find.text('暗色模式'), findsOneWidget);
    });

    testWidgets('dark theme styles preferences cards text and action sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              darkTheme: buildAppDarkTheme(),
              themeMode: ThemeMode.dark,
              home: const PreferencesSettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.byType(AppSectionCard).first;
      final cardDecoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: firstCard,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(cardDecoration.color, AppColors.darkSurface);

      final themeModeText = tester.renderObject<RenderParagraph>(
        find.text('主题模式'),
      );
      expect(themeModeText.text.style?.color, AppColors.darkTextPrimary);

      await tester.tap(find.text('主题模式'));
      await tester.pumpAndSettle();

      final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(bottomSheet.backgroundColor, AppColors.darkSurface);
    });

    testWidgets('settings uses Solana address for Solana chains', (
      tester,
    ) async {
      final account = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository([account]),
            ),
            chainRepositoryProvider.overrideWithValue(
              const _FakeChainRepository(selectedChainId: 'solana-mainnet'),
            ),
          ],
          child: _settingsMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
        listen: false,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await tester.pumpAndSettle();

      expect(find.textContaining('So1111...1112'), findsNothing);
      expect(find.textContaining('0x9858...da94'), findsNothing);
      _expectHighlightedAddress(
        _addressSpanInText(tester, account.solanaAddress),
        account.solanaAddress,
      );
      expect(find.textContaining('Solana Mainnet'), findsOneWidget);
    });

    testWidgets('settings uses Bitcoin address for Bitcoin chains', (
      tester,
    ) async {
      final account = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository([account]),
            ),
            chainRepositoryProvider.overrideWithValue(
              const _FakeChainRepository(selectedChainId: 'bitcoin-mainnet'),
            ),
          ],
          child: _settingsMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
        listen: false,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await tester.pumpAndSettle();

      _expectHighlightedAddress(
        _addressSpanInText(tester, account.btcAddress),
        account.btcAddress,
      );
      expect(find.textContaining('Bitcoin'), findsOneWidget);
    });

    testWidgets('settings hides empty current-chain wallet address', (
      tester,
    ) async {
      final account = WalletAccount(
        id: 'wallet-btc',
        name: 'BTC Wallet',
        evmAddress: '',
        solanaAddress: '',
        btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        source: WalletAccountSource.privateKey,
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository([account]),
            ),
            chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
          ],
          child: _settingsMaterialApp(home: const SettingsPage()),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsPage)),
        listen: false,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await tester.pumpAndSettle();

      expect(find.text('BTC Wallet'), findsOneWidget);
      expect(find.text('当前钱包没有当前链地址'), findsOneWidget);
      expect(find.textContaining('EVM 地址'), findsNothing);
      expect(find.text(account.btcAddress), findsNothing);
    });

    testWidgets('language change persists', (tester) async {
      final store = InMemoryLocalePreferenceStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localePreferenceStoreProvider.overrideWithValue(store)],
          child: _settingsMaterialApp(home: const LanguageSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(await store.readLocaleMode(), AppLocaleMode.en);
    });

    testWidgets(
      'preferences language entry selects language in an action sheet',
      (tester) async {
        final store = InMemoryLocalePreferenceStore();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [localePreferenceStoreProvider.overrideWithValue(store)],
            child: _settingsMaterialApp(home: const PreferencesSettingsPage()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('多语言设置'));
        await tester.pumpAndSettle();

        final actionSheet = find.byType(AppActionSheet<AppLocaleMode>);
        expect(actionSheet, findsOneWidget);
        expect(
          find.descendant(of: actionSheet, matching: find.text('跟随系统')),
          findsOneWidget,
        );
        expect(find.text('简体中文'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        expect(await store.readLocaleMode(), AppLocaleMode.en);
        expect(find.text('English'), findsOneWidget);
        expect(find.byType(LanguageSettingsPage), findsNothing);
      },
    );

    testWidgets('preferences theme color entry opens theme settings', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _settingsMaterialApp(home: const PreferencesSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('主题颜色'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeColorSettingsPage), findsOneWidget);
      expect(find.text('靛蓝'), findsOneWidget);
    });

    testWidgets('theme color settings shows seven preset colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _settingsMaterialApp(home: const ThemeColorSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('靛蓝'), findsOneWidget);
      expect(find.text('蓝色'), findsOneWidget);
      expect(find.text('紫色'), findsOneWidget);
      expect(find.text('绿色'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('玫红'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('橙色'), findsOneWidget);
      expect(find.text('玫红'), findsOneWidget);
    });

    testWidgets('theme color settings includes deep blue preset', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: _settingsMaterialApp(home: const ThemeColorSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('深蓝'), findsOneWidget);
    });

    testWidgets('theme color selection updates immediately', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _settingsMaterialApp(home: const ThemeColorSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('绿色'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ThemeColorSettingsPage)),
        listen: false,
      );
      expect(
        await container.read(themeColorSettingProvider.future),
        AppThemeColor.green,
      );
    });

    testWidgets(
      'security settings clears dApp permissions after confirmation',
      (tester) async {
        final repository = InMemoryDappPermissionRepository();
        await repository.save(
          DappPermission(
            id: dappPermissionId(
              domain: 'app.uniswap.org',
              walletId: 'wallet-1',
              chainId: '1',
            ),
            domain: 'app.uniswap.org',
            walletId: 'wallet-1',
            chainId: '1',
            address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
            grantedAt: DateTime.utc(2026, 6, 6, 12),
            lastUsedAt: DateTime.utc(2026, 6, 6, 12),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dappPermissionRepositoryProvider.overrideWithValue(repository),
            ],
            child: _settingsMaterialApp(home: const SecuritySettingsPage()),
          ),
        );
        await tester.pumpAndSettle();

        final clearPermissions = find.text('清除 dApp 授权');
        await tester.scrollUntilVisible(
          clearPermissions,
          300,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        await tester.tap(clearPermissions);
        await tester.pumpAndSettle();

        expect(find.text('移除站点连接权限'), findsAtLeastNWidgets(1));

        await tester.tap(find.text('确认').last);
        await tester.pumpAndSettle();

        final stored = await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        );
        expect(stored, isNull);
      },
    );

    testWidgets('security settings changes the global wallet password', (
      tester,
    ) async {
      final walletRepository = _FakeWalletRepository([
        WalletAccount(
          id: 'wallet-1',
          name: 'Main Wallet',
          evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(walletRepository),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('修改密码'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('currentPasswordInput')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('newPasswordInput')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('confirmNewPasswordInput')),
        'new-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(walletRepository.changePasswordCallCount, 1);
      expect(walletRepository.lastChangedWalletId, 'wallet-1');
      expect(walletRepository.lastCurrentPassword, 'old-password');
      expect(walletRepository.lastNewPassword, 'new-password');
      expect(find.text('密码已修改'), findsOneWidget);
    });

    testWidgets('security settings requires the current password manually', (
      tester,
    ) async {
      final walletRepository = _FakeWalletRepository([
        WalletAccount(
          id: 'wallet-1',
          name: 'Main Wallet',
          evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
      ]);
      final storage = _FakeSecurePasswordStorage()..password = 'old-password';
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(walletRepository),
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('修改密码'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('currentPasswordInput')),
        'old-password',
      );
      await tester.enterText(
        find.byKey(const Key('newPasswordInput')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('confirmNewPasswordInput')),
        'new-password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(walletRepository.changePasswordCallCount, 1);
      expect(walletRepository.lastCurrentPassword, 'old-password');
      expect(walletRepository.lastNewPassword, 'new-password');
      expect(storage.password, isNull);
    });

    testWidgets('security settings toggles launch password requirement', (
      tester,
    ) async {
      final launchLockStore = InMemoryLaunchLockSettingStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launchLockSettingStoreProvider.overrideWithValue(launchLockStore),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(await launchLockStore.readRequirePasswordOnLaunch(), isTrue);

      await tester.tap(find.byKey(const Key('requirePasswordOnLaunchSwitch')));
      await tester.pumpAndSettle();

      expect(await launchLockStore.readRequirePasswordOnLaunch(), isFalse);

      await tester.tap(find.byKey(const Key('requirePasswordOnLaunchSwitch')));
      await tester.pumpAndSettle();

      expect(await launchLockStore.readRequirePasswordOnLaunch(), isTrue);
    });

    testWidgets('security settings changes the wallet auto-lock duration', (
      tester,
    ) async {
      final autoLockStore = InMemoryWalletAutoLockSettingStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletAutoLockSettingStoreProvider.overrideWithValue(
              autoLockStore,
            ),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('自动锁定'), findsOneWidget);
      expect(find.textContaining('5 分钟'), findsOneWidget);

      await tester.tap(find.byKey(const Key('walletAutoLockRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('walletAutoLockOptionOneHour')));
      await tester.pumpAndSettle();

      expect(await autoLockStore.readDuration(), WalletAutoLockDuration.oneHour);
      expect(find.textContaining('1 小时'), findsOneWidget);
    });

    testWidgets(
      'security settings enables the background privacy shield by default',
      (tester) async {
        final privacyShieldStore =
            InMemoryBackgroundPrivacyShieldSettingStore();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              backgroundPrivacyShieldSettingStoreProvider.overrideWithValue(
                privacyShieldStore,
              ),
            ],
            child: _settingsMaterialApp(home: const SecuritySettingsPage()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('后台隐私遮罩'), findsOneWidget);
        final privacyShieldSwitch = tester.widget<Switch>(
          find.byKey(const Key('backgroundPrivacyShieldSwitch')),
        );
        expect(privacyShieldSwitch.value, isTrue);

        await tester.tap(
          find.byKey(const Key('backgroundPrivacyShieldSwitch')),
        );
        await tester.pumpAndSettle();

        expect(await privacyShieldStore.readEnabled(), isFalse);
      },
    );

    testWidgets('security settings disables saved biometric password', (
      tester,
    ) async {
      final storage = _FakeSecurePasswordStorage()..password = 'saved-password';
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('biometricPasswordSwitch')));
      await tester.pumpAndSettle();

      expect(storage.password, isNull);
    });

    testWidgets('security settings enables biometric password after verifying '
        'the wallet password', (tester) async {
      final walletRepository = _FakeWalletRepository([
        WalletAccount(
          id: 'wallet-1',
          name: 'Main Wallet',
          evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
        WalletAccount(
          id: 'wallet-2',
          name: 'Second Wallet',
          evmAddress: '0x2222222222222222222222222222222222222222',
          solanaAddress: '22222222222222222222222222222222',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
      ]);
      final storage = _FakeSecurePasswordStorage();
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(walletRepository),
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('biometricPasswordSwitch')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('biometricPasswordSetupPasswordInput')),
        'wallet-password',
      );
      await tester.tap(
        find.byKey(const Key('confirmBiometricPasswordSetupButton')),
      );
      await tester.pumpAndSettle();

      expect(walletRepository.unlockCallCount, 2);
      expect(walletRepository.lastUnlockPassword, 'wallet-password');
      expect(storage.password, isNot(contains('wallet-password')));
      expect(storage.password, contains('"version":3'));
      expect(storage.password, contains('"wallet-1"'));
      expect(storage.password, contains('"wallet-2"'));
      expect(
        storage.password,
        contains('"wallet-1":"AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyA="'),
      );
    });

    testWidgets('security settings does not save biometric password when '
        'wallet password verification fails', (tester) async {
      final walletRepository = _FakeWalletRepository([
        WalletAccount(
          id: 'wallet-1',
          name: 'Main Wallet',
          evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          solanaAddress: 'So11111111111111111111111111111111111111112',
          createdAt: DateTime.utc(2026, 6, 6),
          updatedAt: DateTime.utc(2026, 6, 6),
        ),
      ])..unlockError = const WalletError.walletLocked();
      final storage = _FakeSecurePasswordStorage();
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletRepositoryProvider.overrideWithValue(walletRepository),
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('biometricPasswordSwitch')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('biometricPasswordSetupPasswordInput')),
        'wrong-password',
      );
      await tester.tap(
        find.byKey(const Key('confirmBiometricPasswordSetupButton')),
      );
      await tester.pumpAndSettle();

      expect(walletRepository.unlockCallCount, 1);
      expect(storage.password, isNull);
      expect(find.text('钱包已锁定，请先解锁'), findsOneWidget);
    });

    testWidgets('security settings revokes one dApp permission after '
        'confirmation', (tester) async {
      final repository = InMemoryDappPermissionRepository();
      await repository.save(
        DappPermission(
          id: dappPermissionId(
            domain: 'app.uniswap.org',
            walletId: 'wallet-1',
            chainId: '1',
          ),
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
          address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          grantedAt: DateTime.utc(2026, 6, 6, 12),
          lastUsedAt: DateTime.utc(2026, 6, 6, 12),
        ),
      );
      await repository.save(
        DappPermission(
          id: dappPermissionId(
            domain: 'app.curve.fi',
            walletId: 'wallet-1',
            chainId: '1',
          ),
          domain: 'app.curve.fi',
          walletId: 'wallet-1',
          chainId: '1',
          address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          grantedAt: DateTime.utc(2026, 6, 6, 11),
          lastUsedAt: DateTime.utc(2026, 6, 6, 11),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dappPermissionRepositoryProvider.overrideWithValue(repository),
          ],
          child: _settingsMaterialApp(home: const SecuritySettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(find.text('已授权 dApp'), findsOneWidget);
      expect(find.text('app.uniswap.org'), findsOneWidget);
      expect(find.text('app.curve.fi'), findsOneWidget);

      final revokeButton = find.widgetWithText(TextButton, '撤销').first;
      await tester.ensureVisible(revokeButton);
      await tester.pumpAndSettle();
      await tester.tap(revokeButton);
      await tester.pumpAndSettle();

      expect(find.text('撤销 dApp 授权'), findsOneWidget);

      await tester.tap(find.text('撤销').last);
      await tester.pumpAndSettle();

      expect(
        await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNull,
      );
      expect(
        await repository.permissionFor(
          domain: 'app.curve.fi',
          walletId: 'wallet-1',
          chainId: '1',
        ),
        isNotNull,
      );
      expect(find.text('app.uniswap.org'), findsNothing);
      expect(find.text('app.curve.fi'), findsOneWidget);
    });
  });
}

Widget _settingsAppWithProfile({Widget home = const SettingsPage()}) {
  final account = WalletAccount(
    id: 'wallet-1',
    name: 'Main Wallet',
    evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
    solanaAddress: 'So11111111111111111111111111111111111111112',
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  );
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(
        _FakeWalletRepository([account]),
      ),
      chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
      appVersionProvider.overrideWith(
        (ref) async =>
            const AppVersionInfo(version: '9.8.7', buildNumber: '42'),
      ),
    ],
    child: _settingsMaterialApp(home: home),
  );
}

Widget _settingsMaterialApp({required Widget home}) {
  return TranslationProvider(
    child: MaterialApp(theme: buildAppTheme(), home: home),
  );
}

TextSpan _addressSpanInText(WidgetTester tester, String address) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final span = text.textSpan;
    if (span != null && span.toPlainText().contains(address)) {
      return _spanWithPlainText(span, address);
    }
  }
  throw StateError('No Text widget contains $address');
}

TextSpan _spanWithPlainText(InlineSpan span, String plainText) {
  if (span is TextSpan && span.toPlainText() == plainText) {
    return span;
  }
  if (span is TextSpan) {
    for (final child in span.children ?? const <InlineSpan>[]) {
      try {
        return _spanWithPlainText(child, plainText);
      } on StateError {
        continue;
      }
    }
  }
  throw StateError('No TextSpan matches $plainText');
}

void _expectHighlightedAddress(TextSpan span, String address) {
  expect(span.toPlainText(), address);
  final children = span.children!.cast<TextSpan>();
  expect(children[0].text, address.substring(0, 4));
  expect(children[0].style?.color, AppColors.primary);
  expect(children[0].style?.fontWeight, FontWeight.w600);
  expect(children[1].text, address.substring(4, address.length - 5));
  expect(children[2].text, address.substring(address.length - 5));
  expect(children[2].style?.color, AppColors.primary);
  expect(children[2].style?.fontWeight, FontWeight.w600);
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository(this.wallets);

  final List<WalletAccount> wallets;
  int changePasswordCallCount = 0;
  int unlockCallCount = 0;
  String? lastChangedWalletId;
  String? lastCurrentPassword;
  String? lastNewPassword;
  String? lastUnlockPassword;
  Object? unlockError;

  @override
  Future<List<WalletAccount>> getWallets() async => List.unmodifiable(wallets);

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

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
  }) async {
    changePasswordCallCount += 1;
    lastChangedWalletId = walletId;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
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
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCallCount += 1;
    lastUnlockPassword = password;
    final error = unlockError;
    if (error != null) {
      throw error;
    }
    return WalletUnlockResult(
      account: wallets.firstWhere((wallet) => wallet.id == walletId),
      walletDek: List<int>.generate(32, (index) => index + 1),
    );
  }
}

final class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.canAuthenticate,
    required this.authenticateResult,
  });

  final bool canAuthenticate;
  final bool authenticateResult;

  @override
  Future<bool> canAuthenticateWithBiometrics() async => canAuthenticate;

  @override
  Future<bool> authenticate({required String reason}) async {
    return authenticateResult;
  }
}

final class _FakeSecurePasswordStorage implements SecurePasswordStorage {
  String? password;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> savePassword(String password) async {
    this.password = password;
  }

  @override
  Future<void> deletePassword() async {
    password = null;
  }
}

final class _FakeChainRepository implements ChainRepository {
  const _FakeChainRepository({this.selectedChainId = 'ethereum'});

  final String selectedChainId;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> selectChain(String chainId) {
    throw UnimplementedError();
  }
}
