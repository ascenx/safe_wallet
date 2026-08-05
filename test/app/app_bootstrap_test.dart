import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/app/app_bootstrap.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/hive_address_book_repository.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/hive_token_balance_store.dart';
import 'package:safe_wallet/features/assets/data/hive_token_repository.dart';
import 'package:safe_wallet/features/assets/data/token_price_repository.dart';
import 'package:safe_wallet/features/browser/data/hive_browser_state_repository.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/hive_chain_repository.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/dapp/data/hive_dapp_permission_repository.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/hive_rpc_node_repository.dart';
import 'package:safe_wallet/features/onboarding/presentation/onboarding_entry_page.dart';
import 'package:safe_wallet/features/settings/application/background_privacy_shield_setting.dart';
import 'package:safe_wallet/features/settings/application/fiat_currency_setting.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_color_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_mode_setting.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/data/fiat_exchange_rate_repository.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/hive_transaction_history_repository.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/security_logging_wallet_repository.dart';

void main() {
  group('app bootstrap', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_app_bootstrap_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    testWidgets('wires production repositories into the root provider scope', (
      tester,
    ) async {
      final app = await tester.runAsync(() {
        return bootstrapApp(
          storagePath: tempDirectory.path,
          child: const _RepositoryProbe(),
        );
      });
      if (app == null) {
        fail('bootstrapApp did not return a widget');
      }

      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('repositories-ready'), findsOneWidget);
    });

    testWidgets('production empty wallet state reaches onboarding', (
      tester,
    ) async {
      final app = await tester.runAsync(() {
        return bootstrapApp(
          storagePath: tempDirectory.path,
          child: const SafeWalletApp(),
        );
      });
      if (app == null) {
        fail('bootstrapApp did not return a widget');
      }

      await tester.pumpWidget(app);
      await _pumpUntilFound(tester, find.byType(OnboardingEntryPage));

      expect(find.byType(OnboardingEntryPage), findsOneWidget);
    });

    testWidgets('persists the background privacy shield setting', (
      tester,
    ) async {
      final firstApp = await tester.runAsync(() {
        return bootstrapApp(
          storagePath: tempDirectory.path,
          child: const _PrivacyShieldSettingProbe(),
        );
      });
      if (firstApp == null) {
        fail('bootstrapApp did not return a widget');
      }
      await tester.pumpWidget(firstApp);
      await tester.pumpAndSettle();

      expect(find.text('privacy-shield:true'), findsOneWidget);
      final firstContainer = ProviderScope.containerOf(
        tester.element(find.byType(_PrivacyShieldSettingProbe)),
        listen: false,
      );
      await tester.runAsync(() {
        return firstContainer
            .read(backgroundPrivacyShieldSettingProvider.notifier)
            .setEnabled(false);
      });
      await tester.pump();
      expect(find.text('privacy-shield:false'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(Hive.close);
      final restartedApp = await tester.runAsync(() {
        return bootstrapApp(
          storagePath: tempDirectory.path,
          child: const _PrivacyShieldSettingProbe(),
        );
      });
      if (restartedApp == null) {
        fail('bootstrapApp did not return a widget after restart');
      }
      await tester.pumpWidget(restartedApp);
      await tester.pumpAndSettle();

      expect(find.text('privacy-shield:false'), findsOneWidget);
    });
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  fail('Timed out waiting for $finder. Visible texts: $visibleTexts');
}

final class _RepositoryProbe extends ConsumerWidget {
  const _RepositoryProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    expect(
      ref.read(walletRepositoryProvider),
      isA<SecurityLoggingWalletRepository>(),
    );
    expect(
      ref.read(securityLogRepositoryProvider),
      isA<HiveSecurityLogRepository>(),
    );
    expect(
      ref.read(selectedWalletStoreProvider),
      isA<HiveSelectedWalletStore>(),
    );
    expect(
      ref.read(launchLockSettingStoreProvider),
      isA<HiveLaunchLockSettingStore>(),
    );
    expect(
      ref.read(themeColorSettingStoreProvider),
      isA<HiveThemeColorSettingStore>(),
    );
    expect(
      ref.read(themeModeSettingStoreProvider),
      isA<HiveThemeModeSettingStore>(),
    );
    expect(
      ref.read(localePreferenceStoreProvider),
      isA<HiveLocalePreferenceStore>(),
    );
    expect(
      ref.read(fiatCurrencySettingStoreProvider),
      isA<HiveFiatCurrencySettingStore>(),
    );
    expect(
      ref.read(fiatExchangeRateRepositoryProvider),
      isA<DefaultFiatExchangeRateRepository>(),
    );
    expect(ref.read(chainRepositoryProvider), isA<HiveChainRepository>());
    expect(ref.read(rpcNodeRepositoryProvider), isA<HiveRpcNodeRepository>());
    expect(ref.read(tokenRepositoryProvider), isA<HiveTokenRepository>());
    expect(ref.read(tokenBalanceStoreProvider), isA<HiveTokenBalanceStore>());
    expect(
      ref.read(tokenPriceRepositoryProvider),
      isA<DefaultTokenPriceRepository>(),
    );
    expect(
      ref.read(transactionHistoryRepositoryProvider),
      isA<HiveTransactionHistoryRepository>(),
    );
    expect(
      ref.read(dappPermissionRepositoryProvider),
      isA<HiveDappPermissionRepository>(),
    );
    expect(
      ref.read(browserStateRepositoryProvider),
      isA<HiveBrowserStateRepository>(),
    );
    expect(
      ref.read(addressBookRepositoryProvider),
      isA<HiveAddressBookRepository>(),
    );
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Text('repositories-ready'),
    );
  }
}

final class _PrivacyShieldSettingProbe extends ConsumerWidget {
  const _PrivacyShieldSettingProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(backgroundPrivacyShieldSettingProvider);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text('privacy-shield:${setting.value ?? true}'),
    );
  }
}
