import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../features/address_book/application/address_book_controller.dart';
import '../features/address_book/data/hive_address_book_repository.dart';
import '../features/assets/application/asset_portfolio_provider.dart';
import '../features/assets/data/hive_token_balance_store.dart';
import '../features/assets/data/hive_token_price_store.dart';
import '../features/assets/data/token_price_repository.dart';
import '../features/assets/application/token_repository_provider.dart';
import '../features/assets/data/hive_token_repository.dart';
import '../features/browser/data/hive_browser_state_repository.dart';
import '../features/chains/application/available_chains_provider.dart';
import '../features/chains/data/hive_chain_repository.dart';
import '../features/dapp/data/dapp_permission_repository.dart';
import '../features/dapp/data/hive_dapp_permission_repository.dart';
import '../features/i18n/application/locale_controller.dart';
import '../features/i18n/application/locale_preference_store.dart';
import '../features/nodes/application/selected_rpc_node_provider.dart';
import '../features/nodes/data/hive_rpc_node_repository.dart';
import '../features/nodes/data/rpc_credential_store.dart';
import '../features/nodes/data/rpc_credential_migration.dart';
import '../features/settings/application/background_privacy_shield_setting.dart';
import '../features/settings/application/custom_network_creation_service.dart';
import '../features/settings/application/fiat_currency_setting.dart';
import '../features/settings/application/launch_lock_setting.dart';
import '../features/settings/application/theme_color_setting.dart';
import '../features/settings/application/theme_mode_setting.dart';
import '../features/settings/application/wallet_auto_lock_setting.dart';
import '../features/settings/data/fiat_exchange_rate_repository.dart';
import '../features/settings/data/custom_network_data_cleaner.dart';
import '../features/settings/data/security_log_repository.dart';
import '../features/settings/data/wallet_deletion_journal.dart';
import '../features/transfer/application/transaction_history_provider.dart';
import '../features/transfer/data/hive_transaction_history_repository.dart';
import '../features/wallet/application/selected_wallet_controller.dart';
import '../features/wallet/application/wallet_repository_provider.dart';
import '../features/wallet/data/hive_wallet_repository.dart';
import '../features/wallet/data/security_logging_wallet_repository.dart';
import '../features/wallet_connect/application/wallet_connect_project_id_setting.dart';
import '../features/wallet_connect/data/wallet_connect_response_outbox.dart';
import '../shared/storage/storage_initializer.dart';
import '../shared/storage/storage_migration.dart';
import '../shared/security/sensitive_screen_protection.dart';

Future<Widget> bootstrapApp({
  required Widget child,
  String? storagePath,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final usesDefaultStorage = storagePath == null;
  if (usesDefaultStorage) {
    await Hive.initFlutter('safe_wallet');
  }

  final rpcCredentialStore = FlutterSecureRpcCredentialStore();
  final registry = await StorageInitializer(
    path: storagePath,
    migration: StorageMigration(
      migrateV1ToV2: (registry) => RpcCredentialMigration(
        registry: registry,
        credentialStore: rpcCredentialStore,
      ).apply(),
    ),
  ).initialize();
  if (usesDefaultStorage) {
    await excludeWalletStorageFromBackup();
  }
  await RpcCredentialMigration(
    registry: registry,
    credentialStore: rpcCredentialStore,
  ).apply();
  final securityLogRepository = HiveSecurityLogRepository(registry: registry);
  final overrides = [
    walletRepositoryProvider.overrideWithValue(
      SecurityLoggingWalletRepository(
        delegate: HiveWalletRepository(registry: registry),
        securityLogRepository: securityLogRepository,
      ),
    ),
    securityLogRepositoryProvider.overrideWithValue(securityLogRepository),
    walletDeletionJournalProvider.overrideWithValue(
      HiveWalletDeletionJournal(registry: registry),
    ),
    selectedWalletStoreProvider.overrideWithValue(
      HiveSelectedWalletStore(registry: registry),
    ),
    launchLockSettingStoreProvider.overrideWithValue(
      HiveLaunchLockSettingStore(registry: registry),
    ),
    backgroundPrivacyShieldSettingStoreProvider.overrideWithValue(
      HiveBackgroundPrivacyShieldSettingStore(registry: registry),
    ),
    walletAutoLockSettingStoreProvider.overrideWithValue(
      HiveWalletAutoLockSettingStore(registry: registry),
    ),
    localePreferenceStoreProvider.overrideWithValue(
      HiveLocalePreferenceStore(registry: registry),
    ),
    themeColorSettingStoreProvider.overrideWithValue(
      HiveThemeColorSettingStore(registry: registry),
    ),
    themeModeSettingStoreProvider.overrideWithValue(
      HiveThemeModeSettingStore(registry: registry),
    ),
    fiatCurrencySettingStoreProvider.overrideWithValue(
      HiveFiatCurrencySettingStore(registry: registry),
    ),
    walletConnectProjectIdStoreProvider.overrideWithValue(
      HiveWalletConnectProjectIdStore(registry: registry),
    ),
    walletConnectResponseOutboxProvider.overrideWithValue(
      HiveWalletConnectResponseOutbox(registry: registry),
    ),
    fiatExchangeRateRepositoryProvider.overrideWith((ref) {
      final repository = DefaultFiatExchangeRateRepository(
        store: HiveFiatExchangeRateStore(registry: registry),
      );
      ref.onDispose(repository.close);
      return repository;
    }),
    customNetworkDataCleanerProvider.overrideWithValue(
      HiveCustomNetworkDataCleaner(
        registry: registry,
        credentialStore: rpcCredentialStore,
      ),
    ),
    chainRepositoryProvider.overrideWithValue(
      HiveChainRepository(registry: registry),
    ),
    rpcNodeRepositoryProvider.overrideWithValue(
      HiveRpcNodeRepository(
        registry: registry,
        credentialStore: rpcCredentialStore,
      ),
    ),
    rpcCredentialStoreProvider.overrideWithValue(rpcCredentialStore),
    tokenRepositoryProvider.overrideWithValue(
      HiveTokenRepository(registry: registry),
    ),
    tokenBalanceStoreProvider.overrideWithValue(
      HiveTokenBalanceStore(registry: registry),
    ),
    tokenPriceRepositoryProvider.overrideWith((ref) {
      final repository = DefaultTokenPriceRepository(
        store: HiveTokenPriceStore(registry: registry),
      );
      ref.onDispose(repository.close);
      return repository;
    }),
    transactionHistoryRepositoryProvider.overrideWithValue(
      HiveTransactionHistoryRepository(registry: registry),
    ),
    dappPermissionRepositoryProvider.overrideWithValue(
      HiveDappPermissionRepository(registry: registry),
    ),
    browserStateRepositoryProvider.overrideWithValue(
      HiveBrowserStateRepository(registry: registry),
    ),
    addressBookRepositoryProvider.overrideWithValue(
      HiveAddressBookRepository(registry: registry),
    ),
  ];

  return ProviderScope(overrides: overrides, child: child);
}
