import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/evm_contract_call_controller.dart';
import 'package:safe_wallet/features/advanced/data/evm_contract_call_gateway.dart';
import 'package:safe_wallet/features/advanced/presentation/evm_contract_call_page.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';
import 'package:safe_wallet/shared/widgets/app_action_sheet.dart';
import 'package:safe_wallet/shared/widgets/app_picker_field.dart';

void main() {
  testWidgets('selects an EVM network without API or EVM-only notices', (
    tester,
  ) async {
    final gateway = _PageGateway()
      ..readResult = '0x${BigInt.one.toRadixString(16).padLeft(64, '0')}';

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('evmContractNetworkPicker')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.byType(AppPickerField), findsNWidgets(4));
    expect(find.textContaining('API Key'), findsNothing);
    expect(find.textContaining('仅支持 EVM'), findsNothing);

    await tester.tap(find.byKey(const Key('evmContractNetworkPicker')));
    await tester.pumpAndSettle();
    expect(find.byType(AppActionSheet<ChainConfig>), findsOneWidget);
    await tester.tap(find.text(_bscChain.name).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('evmContractAddressInput')),
      _contractAddress,
    );
    await tester.tap(find.byKey(const Key('evmContractFunctionPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('balanceOf(address)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('evmContractArgument0')),
      _walletAddress,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('evmContractExecuteButton')));
    await tester.pumpAndSettle();

    expect(gateway.lastRpcUrl, _bscNode.endpointUrl);
  });

  testWidgets('reads a standard ERC20 function and displays decoded output', (
    tester,
  ) async {
    final gateway = _PageGateway()
      ..readResult = '0x${BigInt.from(42).toRadixString(16).padLeft(64, '0')}';
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('evmContractAddressInput')),
      _contractAddress,
    );
    await tester.tap(find.byKey(const Key('evmContractFunctionPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('balanceOf(address)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('evmContractArgument0')),
      _walletAddress,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('evmContractExecuteButton')));
    await tester.pumpAndSettle();

    expect(find.text('1. 42'), findsOneWidget);
    expect(gateway.lastCalldata, startsWith('0x70a08231'));

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('evmContractCopyResult0')));
    await tester.pump();

    expect(copiedText, '42');
    expect(find.text('调用结果已复制'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('prepares, confirms, and submits an ERC20 write', (
    tester,
  ) async {
    final gateway = _PageGateway()..transactionHash = '0xsubmitted';
    final history = _PageHistoryRepository();
    final cache = SessionKeyCache()
      ..unlock(
        walletId: _account.id,
        walletDek: const [1, 2, 3],
        now: DateTime.now().toUtc(),
      );

    await tester.pumpWidget(
      _app(gateway, history: history, sessionKeyCache: cache),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('evmContractAddressInput')),
      _contractAddress,
    );
    await tester.tap(find.byKey(const Key('evmContractFunctionPicker')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('appActionSheetActionList')),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('transfer(address,uint256)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('evmContractArgument0')),
      _walletAddress,
    );
    await tester.enterText(
      find.byKey(const Key('evmContractArgument1')),
      '1',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('evmContractExecuteButton')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('确认合约写入'), findsOneWidget);
    await tester.tap(find.text('确认并签名'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0xsubmitted'), findsOneWidget);
    expect(gateway.prepareWriteCount, 1);
    expect(gateway.sendWriteCount, 1);
    expect(gateway.lastPrivateKey, '01');
    expect(history.records, hasLength(1));
    expect(history.records.single.memo, 'transfer(address,uint256)');
  });
}

Widget _app(
  _PageGateway gateway, {
  _PageHistoryRepository? history,
  SessionKeyCache? sessionKeyCache,
}) {
  return ProviderScope(
    overrides: [
      assetPortfolioRequestProvider.overrideWithValue(Future.value(_request)),
      availableChainsProvider.overrideWith(
        (ref) async => [_chain, _bscChain],
      ),
      selectedResolvedRpcNodeProvider(_bscChain).overrideWith(
        (ref) async => _bscNode,
      ),
      evmContractCallGatewayProvider.overrideWithValue(gateway),
      walletRepositoryProvider.overrideWithValue(_PageWalletRepository()),
      transactionHistoryRepositoryProvider.overrideWithValue(
        history ?? _PageHistoryRepository(),
      ),
      if (sessionKeyCache != null)
        sessionKeyCacheProvider.overrideWithValue(sessionKeyCache),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const EvmContractCallPage(),
      ),
    ),
  );
}

final _chain = defaultChains.first;
final _bscChain = defaultChains[1];
const _walletAddress = '0x2222222222222222222222222222222222222222';
const _contractAddress = '0x1111111111111111111111111111111111111111';
final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: _walletAddress,
  solanaAddress: '',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);
final _request = AssetPortfolioRequest(
  account: _account,
  chain: _chain,
  rpcNode: const RpcNode(
    id: 'rpc-1',
    chainId: '1',
    name: 'RPC',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);
const _bscNode = RpcNode(
  id: 'rpc-56',
  chainId: '56',
  name: 'BSC RPC',
  url: 'https://bsc-rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

final class _PageGateway implements EvmContractCallGateway {
  String readResult = '0x';
  String transactionHash = '0xhash';
  String? lastCalldata;
  String? lastRpcUrl;
  String? lastPrivateKey;
  int prepareWriteCount = 0;
  int sendWriteCount = 0;

  @override
  Future<bool> hasContractCode({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async =>
      true;

  @override
  Future<String> read({
    required String rpcUrl,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    Map<String, String> headers = const {},
  }) async {
    lastRpcUrl = rpcUrl;
    lastCalldata = calldata;
    return readResult;
  }

  @override
  Future<EvmContractWritePreparation> prepareWrite({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    required BigInt valueWei,
    Map<String, String> headers = const {},
  }) async {
    prepareWriteCount += 1;
    lastCalldata = calldata;
    return EvmContractWritePreparation(
      chainId: chainId,
      fromAddress: fromAddress,
      contractAddress: contractAddress,
      calldata: calldata,
      valueWei: valueWei,
      gasLimit: 30000,
      gasPriceWei: BigInt.from(1000000000),
      nonce: 7,
    );
  }

  @override
  Future<String> sendWrite({
    required String rpcUrl,
    required String privateKey,
    required EvmContractWritePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    sendWriteCount += 1;
    lastPrivateKey = privateKey;
    return transactionHash;
  }
}

final class _PageHistoryRepository implements TransactionHistoryRepository {
  final records = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async => records;

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async =>
      records.take(limit).toList();

  @override
  Future<void> save(TransactionRecord record) async {
    records.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _PageWalletRepository implements WalletRepository {
  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(evmPrivateKey: '01');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
