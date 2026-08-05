import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/dapp/domain/dapp_permission.dart';
import 'package:safe_wallet/features/settings/application/settings_controller.dart';
import 'package:safe_wallet/features/settings/data/wallet_deletion_journal.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_controller.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';

void main() {
  test(
    'deleting a wallet clears wallet-scoped security and history state',
    () async {
      final repository = _WalletRepository();
      final history = _HistoryRepository();
      final permissions = InMemoryDappPermissionRepository();
      final secureStorage = _SecureStorage();
      final biometricStore = BiometricPasswordStore(
        authenticator: const _Authenticator(),
        storage: secureStorage,
      );
      final container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(repository),
          transactionHistoryRepositoryProvider.overrideWithValue(history),
          dappPermissionRepositoryProvider.overrideWithValue(permissions),
          biometricPasswordStoreProvider.overrideWithValue(biometricStore),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(selectedWalletIdProvider.notifier)
          .select(_account.id);
      await container
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: _account.id, password: 'password', now: _now);
      await permissions.save(
        DappPermission(
          id: 'permission',
          domain: 'example.com',
          walletId: _account.id,
          chainId: '1',
          address: _account.evmAddress,
          grantedAt: _now,
          lastUsedAt: _now,
        ),
      );
      await history.save(
        TransactionRecord(
          id: 'tx',
          walletId: _account.id,
          chainId: '1',
          chainType: ChainType.evm,
          assetSymbol: 'ETH',
          direction: TransactionDirection.outgoing,
          amount: '1',
          status: TransactionStatus.submitted,
          transactionHash: '0xhash',
          createdAt: _now,
        ),
      );
      await biometricStore.saveWalletKey(
        walletId: _account.id,
        walletDek: List<int>.filled(32, 7),
      );

      await container
          .read(settingsControllerProvider.notifier)
          .deleteWallet(walletId: _account.id, password: 'password');

      expect(await repository.getWallets(), isEmpty);
      expect(container.read(selectedWalletIdProvider), isNull);
      expect(
        container.read(walletSessionControllerProvider).value?.isUnlocked,
        isFalse,
      );
      expect(await permissions.listAll(), isEmpty);
      expect(await history.listForWallet(walletId: _account.id), isEmpty);
      expect(await biometricStore.hasSavedPassword(), isFalse);
    },
  );

  test(
    'pending wallet cleanup resumes after the controller is rebuilt',
    () async {
      final repository = _WalletRepository();
      final history = _HistoryRepository()..deleteError = StateError('disk');
      final permissions = InMemoryDappPermissionRepository();
      final secureStorage = _SecureStorage();
      final biometricStore = BiometricPasswordStore(
        authenticator: const _Authenticator(),
        storage: secureStorage,
      );
      final journal = InMemoryWalletDeletionJournal();
      final selectedWalletStore = InMemorySelectedWalletStore();
      final walletConnectGateway = _WalletConnectGateway();
      await selectedWalletStore.writeSelectedWalletId(_account.id);
      await permissions.save(
        DappPermission(
          id: 'permission',
          domain: 'example.com',
          walletId: _account.id,
          chainId: '1',
          address: _account.evmAddress,
          grantedAt: _now,
          lastUsedAt: _now,
        ),
      );
      await history.save(
        TransactionRecord(
          id: 'tx',
          walletId: _account.id,
          chainId: '1',
          chainType: ChainType.evm,
          assetSymbol: 'ETH',
          direction: TransactionDirection.outgoing,
          amount: '1',
          status: TransactionStatus.submitted,
          transactionHash: '0xhash',
          createdAt: _now,
        ),
      );
      await biometricStore.saveWalletKey(
        walletId: _account.id,
        walletDek: List<int>.filled(32, 7),
      );

      ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(repository),
          transactionHistoryRepositoryProvider.overrideWithValue(history),
          dappPermissionRepositoryProvider.overrideWithValue(permissions),
          biometricPasswordStoreProvider.overrideWithValue(biometricStore),
          walletDeletionJournalProvider.overrideWithValue(journal),
          selectedWalletStoreProvider.overrideWithValue(selectedWalletStore),
          walletConnectGatewayProvider.overrideWithValue(walletConnectGateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
        ],
      );

      final firstContainer = createContainer();
      await expectLater(
        firstContainer
            .read(settingsControllerProvider.notifier)
            .deleteWallet(walletId: _account.id, password: 'password'),
        throwsStateError,
      );
      firstContainer.dispose();

      expect(await repository.getWallets(), isEmpty);
      expect(await journal.read(), isNotNull);
      expect(await permissions.listAll(), isNotEmpty);
      expect(await biometricStore.hasSavedPassword(), isTrue);

      history.deleteError = null;
      final secondContainer = createContainer();
      addTearDown(secondContainer.dispose);
      await secondContainer.read(settingsControllerProvider.future);

      expect(await journal.read(), isNull);
      expect(await history.listForWallet(walletId: _account.id), isEmpty);
      expect(await permissions.listAll(), isEmpty);
      expect(await biometricStore.hasSavedPassword(), isFalse);
      expect(secondContainer.read(selectedWalletIdProvider), isNull);
      expect(walletConnectGateway.initializeCalls, 1);
      expect(walletConnectGateway.disconnectedTopics, ['topic-a']);
    },
  );
}

final _now = DateTime.utc(2026, 8, 2);

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '',
  createdAt: _now,
  updatedAt: _now,
);

final class _WalletRepository implements WalletRepository {
  final _wallets = <WalletAccount>[_account];

  @override
  Future<List<WalletAccount>> getWallets() async => List.of(_wallets);

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    _wallets.removeWhere((wallet) => wallet.id == walletId);
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async =>
      WalletUnlockResult(account: _account, walletDek: List.filled(32, 7));

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();
  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();
  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) => throw UnimplementedError();
  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();
  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) => throw UnimplementedError();
  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) => throw UnimplementedError();
  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) => throw UnimplementedError();
}

final class _HistoryRepository
    implements
        TransactionHistoryRepository,
        WalletScopedTransactionHistoryRepository {
  Object? deleteError;
  final records = <TransactionRecord>[];

  @override
  Future<void> save(TransactionRecord record) async => records.add(record);
  @override
  Future<void> deleteForWallet(String walletId) async {
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    records.removeWhere((record) => record.walletId == walletId);
  }

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async =>
      List.of(records);
  @override
  Future<List<TransactionRecord>> listForWallet({
    required String walletId,
    String? chainId,
  }) async => records.where((record) => record.walletId == walletId).toList();
  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async => records.take(limit).toList();
  @override
  Future<List<TransactionRecord>> recentForWallet({
    required String walletId,
    int limit = 4,
    String? chainId,
  }) async => (await listForWallet(walletId: walletId)).take(limit).toList();
  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _SecureStorage implements SecurePasswordStorage {
  String? value;
  @override
  Future<void> deletePassword() async => value = null;
  @override
  Future<String?> readPassword() async => value;
  @override
  Future<void> savePassword(String password) async => value = password;
}

final class _Authenticator implements BiometricAuthenticator {
  const _Authenticator();
  @override
  Future<bool> authenticate({required String reason}) async => true;
  @override
  Future<bool> canAuthenticateWithBiometrics() async => true;
}

final class _WalletConnectGateway extends UnsupportedWalletConnectGateway {
  int initializeCalls = 0;
  final disconnectedTopics = <String>[];
  final sessions = <WalletConnectSession>[
    WalletConnectSession(
      topic: 'topic-a',
      pairingTopic: 'pairing-a',
      peer: const WalletConnectPeerMetadata(
        name: 'dApp',
        description: '',
        url: 'https://example.com',
        icons: [],
      ),
      namespaces: {
        'eip155': WalletConnectApprovedNamespace(
          chains: {const Caip2ChainId(namespace: 'eip155', reference: '1')},
          accounts: {
            const Caip10AccountId(
              chain: Caip2ChainId(namespace: 'eip155', reference: '1'),
              address: '0x1111111111111111111111111111111111111111',
            ),
          },
          methods: const {'personal_sign'},
          events: const {},
        ),
      },
      expiry: DateTime.utc(2030),
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {
    initializeCalls += 1;
  }

  @override
  Future<List<WalletConnectSession>> getActiveSessions() async =>
      List.of(sessions);

  @override
  Future<void> disconnect(String topic) async {
    disconnectedTopics.add(topic);
    sessions.removeWhere((session) => session.topic == topic);
  }
}
