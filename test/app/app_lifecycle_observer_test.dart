import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app_lifecycle_observer.dart';
import 'package:safe_wallet/features/address_book/presentation/edit_contact_page.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/settings/application/background_privacy_shield_setting.dart';
import 'package:safe_wallet/features/settings/application/wallet_auto_lock_setting.dart';
import 'package:safe_wallet/features/staking/application/tron_staking_dashboard_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  final baseTime = DateTime.utc(2026, 6, 6, 12);

  testWidgets('backgrounding locks the wallet and hides pushed pages', (
    tester,
  ) async {
    final cache = SessionKeyCache();
    final container = _container(
      cache: cache,
      autoLockStore: InMemoryWalletAutoLockSettingStore(
        duration: WalletAutoLockDuration.immediately,
      ),
    );
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          theme: buildAppTheme(),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    await tester.tap(find.text('Open secret'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive details'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('appPrivacyShield')), findsOneWidget);
    final privacyBlur = tester.widget<BackdropFilter>(
      find.descendant(
        of: find.byKey(const Key('appPrivacyShield')),
        matching: find.byType(BackdropFilter),
      ),
    );
    expect(privacyBlur.filter.toString(), contains('12.0'));
    final privacyTint = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const Key('appPrivacyShield')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(privacyTint.color, AppColors.background.withValues(alpha: 0.1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    final session = container.read(walletSessionControllerProvider).value;
    expect(session?.isUnlocked, isFalse);
    expect(cache.readKey(_account.id, now: baseTime), isNull);
    expect(find.byKey(const Key('appPrivacyShield')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appPrivacyShield')), findsNothing);
    expect(find.text('Sensitive details'), findsNothing);
    expect(find.text('Open secret'), findsOneWidget);
  });

  testWidgets('temporary inactive state keeps the wallet and route active', (
    tester,
  ) async {
    final cache = SessionKeyCache();
    final container = _container(cache: cache);
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    await tester.tap(find.text('Open secret'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive details'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    final session = container.read(walletSessionControllerProvider).value;
    expect(session?.isUnlocked, isTrue);
    expect(cache.readKey(_account.id, now: baseTime), isNotNull);
    expect(find.byKey(const Key('appPrivacyShield')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appPrivacyShield')), findsNothing);
    expect(find.text('Sensitive details'), findsOneWidget);
  });

  testWidgets('resuming before auto-lock timeout keeps session and route', (
    tester,
  ) async {
    var lifecycleNow = baseTime;
    final cache = SessionKeyCache();
    final container = _container(
      cache: cache,
      lifecycleClock: () => lifecycleNow,
    );
    await container.read(walletAutoLockSettingProvider.future);
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );
    await tester.tap(find.text('Open secret'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    lifecycleNow = baseTime.add(const Duration(minutes: 4));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      container.read(walletSessionControllerProvider).value?.isUnlocked,
      isTrue,
    );
    expect(cache.readKey(_account.id, now: lifecycleNow), isNotNull);
    expect(find.text('Sensitive details'), findsOneWidget);
  });

  testWidgets('resuming after auto-lock timeout locks and hides route', (
    tester,
  ) async {
    var lifecycleNow = baseTime;
    final cache = SessionKeyCache();
    final container = _container(
      cache: cache,
      lifecycleClock: () => lifecycleNow,
    );
    await container.read(walletAutoLockSettingProvider.future);
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );
    await tester.tap(find.text('Open secret'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    lifecycleNow = baseTime.add(const Duration(minutes: 6));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      container.read(walletSessionControllerProvider).value?.isUnlocked,
      isFalse,
    );
    expect(cache.readKey(_account.id, now: lifecycleNow), isNull);
    expect(find.text('Sensitive details'), findsNothing);
    expect(find.text('Open secret'), findsOneWidget);
  });

  testWidgets('backgrounding keeps a preserved form route and its draft', (
    tester,
  ) async {
    final cache = SessionKeyCache();
    final container = _container(
      cache: cache,
      autoLockStore: InMemoryWalletAutoLockSettingStore(
        duration: WalletAutoLockDuration.immediately,
      ),
    );
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draft contact');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Draft contact',
    );
    expect(find.byKey(const Key('contactChainTypeSelector')), findsOneWidget);
    expect(
      container.read(walletSessionControllerProvider).value?.isUnlocked,
      isFalse,
    );
  });

  testWidgets(
    'disabled privacy shield still locks and hides sensitive pages in background',
    (tester) async {
      final cache = SessionKeyCache();
      final container = _container(
        cache: cache,
        privacyShieldStore: InMemoryBackgroundPrivacyShieldSettingStore(
          enabled: false,
        ),
        autoLockStore: InMemoryWalletAutoLockSettingStore(
          duration: WalletAutoLockDuration.immediately,
        ),
      );
      await container
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: _account.id, password: 'password', now: baseTime);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: container.read(appNavigatorKeyProvider),
            home: const AppLifecycleObserver(child: _RootPage()),
          ),
        ),
      );
      await tester.tap(find.text('Open secret'));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      final session = container.read(walletSessionControllerProvider).value;
      expect(find.byKey(const Key('appPrivacyShield')), findsNothing);
      expect(session?.isUnlocked, isFalse);
      expect(cache.readKey(_account.id, now: baseTime), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Sensitive details'), findsNothing);
      expect(find.text('Open secret'), findsOneWidget);
    },
  );

  testWidgets('resume expires an overdue wallet session', (tester) async {
    final container = _container(
      cache: SessionKeyCache(
        timeout: WalletSessionController.unlockDuration,
      ),
      lifecycleNow: baseTime.add(WalletSessionController.unlockDuration),
    );
    await container
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: _account.id, password: 'password', now: baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final session = container.read(walletSessionControllerProvider).value;
    expect(session?.isUnlocked, isFalse);
  });

  testWidgets('resume keeps asset portfolio live refresh throttle', (
    tester,
  ) async {
    final container = _container(cache: SessionKeyCache());
    const refreshKey = 'evm:1:0x1111111111111111111111111111111111111111';
    container
        .read(assetPortfolioLiveRefreshRegistryProvider)
        .markStarted(refreshKey, baseTime);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      container
          .read(assetPortfolioLiveRefreshRegistryProvider)
          .lastStartedAt(refreshKey),
      baseTime,
    );
  });

  testWidgets('resume invalidates the TRX staking dashboard', (tester) async {
    _stakingDashboardBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
        sessionKeyCacheProvider.overrideWithValue(SessionKeyCache()),
        tronStakingDashboardControllerProvider.overrideWith(
          _CountingStakingDashboardController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tronStakingDashboardControllerProvider.future);
    expect(_stakingDashboardBuilds, 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: container.read(appNavigatorKeyProvider),
          home: const AppLifecycleObserver(child: _RootPage()),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await container.read(tronStakingDashboardControllerProvider.future);

    expect(_stakingDashboardBuilds, 2);
  });
}

int _stakingDashboardBuilds = 0;

final class _CountingStakingDashboardController
    extends TronStakingDashboardController {
  @override
  Future<TronStakingDashboardState> build() async {
    _stakingDashboardBuilds += 1;
    return TronStakingDashboardState(
      wallets: const [],
      networks: const [],
      selectedWalletId: null,
      selectedNetworkId: null,
      rpcNode: null,
      overview: null,
      delegations: const [],
      witnesses: const [],
    );
  }
}

ProviderContainer _container({
  required SessionKeyCache cache,
  DateTime? lifecycleNow,
  AppLifecycleClock? lifecycleClock,
  BackgroundPrivacyShieldSettingStore? privacyShieldStore,
  WalletAutoLockSettingStore? autoLockStore,
}) {
  final container = ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      sessionKeyCacheProvider.overrideWithValue(cache),
      if (privacyShieldStore != null)
        backgroundPrivacyShieldSettingStoreProvider.overrideWithValue(
          privacyShieldStore,
        ),
      if (autoLockStore != null)
        walletAutoLockSettingStoreProvider.overrideWithValue(autoLockStore),
      if (lifecycleNow != null)
        appLifecycleClockProvider.overrideWithValue(() => lifecycleNow),
      if (lifecycleClock != null)
        appLifecycleClockProvider.overrideWithValue(lifecycleClock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final class _RootPage extends StatelessWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('Sensitive details')),
                    ),
                  ),
                );
              },
              child: const Text('Open secret'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditContactPage(),
                  ),
                );
              },
              child: const Text('Open form'),
            ),
          ],
        ),
      ),
    );
  }
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Main Wallet',
  evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final class _FakeWalletRepository implements WalletRepository {
  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

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
    return WalletUnlockResult(account: _account, walletDek: [1, 2, 3, 4]);
  }
}
