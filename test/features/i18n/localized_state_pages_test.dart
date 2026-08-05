import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/address_book_repository.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/address_book/presentation/contact_picker_sheet.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/presentation/solana_dapp_test_page.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_broadcast_controller.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/evm_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/transfer/presentation/scan_page.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_history_page.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_result_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  setUp(() async {
    await LocaleSettings.setLocale(AppLocale.en);
  });

  tearDown(() async {
    await LocaleSettings.setLocale(AppLocale.zh);
  });

  group('English state page localization', () {
    testWidgets('scan page states do not expose Han text', (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const ScanPage(
            initialScanValue: 'not an address',
            autoNavigate: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('The QR code is not a valid address.'), findsOneWidget);
      _expectNoVisibleHanText(tester);

      await tester.pumpWidget(
        _localizedApp(
          const ScanPage(
            initialScanValue: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
            autoNavigate: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Address detected'), findsOneWidget);
      _expectNoVisibleHanText(tester);
    });

    testWidgets('successful transfer result does not expose Han text',
        (tester) async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final container = _transactionContainer(
        evmService: _FakeEvmTransactionService(result: '0xresult'),
        historyRepository: _FakeTransactionHistoryRepository(),
      );
      addTearDown(container.dispose);
      await _unlock(container);
      final request = _broadcastRequest(chain: ethereum);
      await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(request);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _localizedApp(
            TransactionResultPage(
              request: request,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('0xresult'), findsOneWidget);
      _expectNoVisibleHanText(tester);
    });

    testWidgets('populated transaction history does not expose Han text',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionHistoryRepositoryProvider.overrideWithValue(
              _FakeTransactionHistoryRepository(records: [
                _record(
                  id: 'incoming-success',
                  direction: TransactionDirection.incoming,
                  status: TransactionStatus.success,
                ),
                _record(
                  id: 'outgoing-failed',
                  direction: TransactionDirection.outgoing,
                  status: TransactionStatus.failed,
                ),
              ]),
            ),
          ],
          child: _localizedApp(const TransactionHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Receive'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      _expectNoVisibleHanText(tester);
    });

    testWidgets('Solana dApp boundary page does not expose Han text',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chainRepositoryProvider.overrideWithValue(
              _FakeChainRepository(selectedChainId: 'solana-mainnet'),
            ),
            walletRepositoryProvider.overrideWithValue(
              const _FakeWalletRepository(),
            ),
          ],
          child: _localizedApp(const SolanaDappTestPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solana dApp Test'), findsWidgets);
      expect(find.text('Solana dApp Interface Reserved'), findsOneWidget);
      _expectNoVisibleHanText(tester);
    });

    testWidgets('contact picker empty state does not expose Han text',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addressBookRepositoryProvider.overrideWithValue(
              const _FakeAddressBookRepository(),
            ),
          ],
          child: _localizedApp(
            const ContactPickerSheet(chainType: ChainType.evm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Contact'), findsOneWidget);
      expect(find.text('No contacts for the current chain'), findsOneWidget);
      expect(find.byKey(const Key('appDragHandle')), findsOneWidget);
      final handlePadding = tester.widget<Padding>(
        find.byKey(const Key('appDragHandle')),
      );
      expect(
        handlePadding.padding,
        const EdgeInsets.symmetric(vertical: 12),
      );
      _expectNoVisibleHanText(tester);
    });
  });
}

Widget _localizedApp(Widget home) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: home),
      ),
    ),
  );
}

void _expectNoVisibleHanText(WidgetTester tester) {
  final hanPattern = RegExp(r'[\u4e00-\u9fff]');
  final visibleHanTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .where(hanPattern.hasMatch)
      .toList(growable: false);
  expect(visibleHanTexts, isEmpty);
}

ProviderContainer _transactionContainer({
  required EvmTransactionService evmService,
  required TransactionHistoryRepository historyRepository,
}) {
  return ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(const _FakeWalletRepository()),
      sessionKeyCacheProvider.overrideWithValue(SessionKeyCache()),
      transactionHistoryRepositoryProvider.overrideWithValue(historyRepository),
      transactionBroadcastClockProvider.overrideWithValue(() => _now),
      evmTransactionServiceProvider.overrideWithValue(evmService),
    ],
  );
}

Future<void> _unlock(ProviderContainer container) async {
  await container.read(walletSessionControllerProvider.notifier).unlock(
        walletId: _account.id,
        password: 'password',
        now: _now,
      );
}

TransactionBroadcastRequest _broadcastRequest({required ChainConfig chain}) {
  return TransactionBroadcastRequest(
    chain: chain,
    rpcNode: RpcNode(
      id: '${chain.id}-node',
      chainId: chain.chainId,
      name: 'Test RPC',
      url: 'https://rpc.example.com',
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    ),
    account: _account,
    transaction: TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: '0x2222222222222222222222222222222222222222',
      amount: '0.1',
      amountInBaseUnits: '100000000000000000',
      tokenDecimals: 18,
      transactionType: TransactionType.nativeTransfer,
    ),
    feeEstimate: FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    ),
  );
}

TransactionRecord _record({
  required String id,
  required TransactionDirection direction,
  required TransactionStatus status,
}) {
  return TransactionRecord(
    id: id,
    chainId: '1',
    chainType: ChainType.evm,
    assetSymbol: 'ETH',
    direction: direction,
    amount: '0.1',
    status: status,
    transactionHash: '0xhash-$id',
    createdAt: _now,
    fromAddress: '0x1111111111111111111111111111111111111111',
    toAddress: '0x2222222222222222222222222222222222222222',
  );
}

final _now = DateTime.utc(2026, 6, 6, 12);

const _evmPrivateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: _now,
  updatedAt: _now,
);

final class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository();

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
  Future<List<WalletAccount>> getWallets() async => [_account];

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
  }) async =>
      WalletKeyMaterial(evmPrivateKey: _evmPrivateKey);

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
  }) async =>
      WalletUnlockResult(account: _account, walletDek: [1, 2, 3, 4]);
}

final class _FakeEvmTransactionService implements EvmTransactionService {
  const _FakeEvmTransactionService({required this.result});

  final String result;

  @override
  Future<String> signAndBroadcast(EvmTransactionBroadcastInput input) async {
    return result;
  }
}

final class _FakeTransactionHistoryRepository
    implements TransactionHistoryRepository {
  const _FakeTransactionHistoryRepository({this.records = const []});

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return records
        .where((record) => chainId == null || record.chainId == chainId)
        .toList(growable: false);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return (await list(chainId: chainId)).take(limit).toList(growable: false);
  }

  @override
  Future<void> save(TransactionRecord record) async {}

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _FakeChainRepository implements ChainRepository {
  const _FakeChainRepository({required this.selectedChainId});

  final String selectedChainId;

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
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    return defaultChains.firstWhere((chain) => chain.id == chainId);
  }
}

final class _FakeAddressBookRepository implements AddressBookRepository {
  const _FakeAddressBookRepository();

  @override
  Future<void> deleteContact(String contactId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AddressBookContact>> listContacts() async => const [];

  @override
  Future<AddressBookContact> saveContact(AddressBookContact contact) {
    throw UnimplementedError();
  }
}
