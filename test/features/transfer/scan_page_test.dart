import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/transfer_draft_controller.dart';
import 'package:safe_wallet/features/transfer/presentation/scan_page.dart';
import 'package:safe_wallet/features/transfer/presentation/transfer_page.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/utils/address_parser.dart';

void main() {
  test('address parser accepts EVM, Bitcoin, and Solana addresses', () {
    final evm = parseWalletAddress(
      'ethereum:0x9858effd232b4033e47d90003d41ec34ecaeda94',
    );
    final bitcoin = parseWalletAddress(
      'bitcoin:bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    );
    final solana = parseWalletAddress(
      'solana:11111111111111111111111111111111',
    );

    expect(evm?.address, '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(evm?.chainType.name, 'evm');
    expect(bitcoin?.address, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
    expect(bitcoin?.chainType, ChainType.bitcoin);
    expect(solana?.address, '11111111111111111111111111111111');
    expect(solana?.chainType.name, 'solana');
  });

  test('address parser recognizes raw and explicit Sui addresses', () {
    const address =
        '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133';

    final raw = parseWalletAddress(address);
    final short = parseWalletAddress('sui:0x2');

    expect(raw?.chainType, ChainType.sui);
    expect(raw?.address, address);
    expect(short?.chainType, ChainType.sui);
    expect(
      short?.address,
      '0x0000000000000000000000000000000000000000000000000000000000000002',
    );
  });

  test('address parser accepts Bitcoin address and amount URI parameters', () {
    final raw = parseWalletAddress(
      'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    );
    final withAmount = parseWalletAddress(
      'bitcoin:bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu?amount=0.001',
    );
    final withValue = parseWalletAddress(
      'bitcoin:bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu?value=0.002',
    );

    expect(raw?.address, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
    expect(raw?.chainType, ChainType.bitcoin);
    expect(withAmount?.amount, '0.001');
    expect(withValue?.amount, '0.002');
  });

  test('address parser gives amount priority over value', () {
    final parsed = parseWalletAddress(
      'bitcoin:bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu'
      '?value=0.002&amount=0.001',
    );

    expect(parsed?.chainType, ChainType.bitcoin);
    expect(parsed?.amount, '0.001');
  });

  test('address parser treats legacy Bitcoin base58 addresses as Bitcoin', () {
    final raw = parseWalletAddress('1BoatSLRHtKNngkdXEeobR76b53LETtpyT');
    final withAmount = parseWalletAddress(
      'bitcoin:1BoatSLRHtKNngkdXEeobR76b53LETtpyT?amount=0.001',
    );

    expect(raw?.address, '1BoatSLRHtKNngkdXEeobR76b53LETtpyT');
    expect(raw?.chainType, ChainType.bitcoin);
    expect(withAmount?.chainType, ChainType.bitcoin);
    expect(withAmount?.amount, '0.001');
  });

  test('address parser accepts EIP-681 chain id and transfer parameters', () {
    final native = parseWalletAddress(
      'ethereum:0x9858effd232b4033e47d90003d41ec34ecaeda94@56'
      '?value=1000000000000000000&label=Main%20Wallet',
    );
    final tokenTransfer = parseWalletAddress(
      'ethereum:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48@1'
      '/transfer?address=0x1111111111111111111111111111111111111111'
      '&uint256=1000000',
    );

    expect(native?.address, '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(native?.chainType.name, 'evm');
    expect(native?.amount, '1');
    expect(
      tokenTransfer?.address,
      '0x1111111111111111111111111111111111111111',
    );
    expect(tokenTransfer?.chainType.name, 'evm');
    expect(
      tokenTransfer?.contractAddress,
      '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
    );
  });

  testWidgets('scanned EIP-681 chain id selects the exact EVM network', (
    tester,
  ) async {
    final bnb = defaultChains.firstWhere(
      (chain) => chain.id == 'bnb-smart-chain',
    );
    final repository = _FakeChainRepository(selectedChain: bnb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chainRepositoryProvider.overrideWithValue(repository)],
        child: _scanApp(
          const ScanPage(
            initialScanValue:
                'ethereum:0x9858effd232b4033e47d90003d41ec34ecaeda94@1',
            autoNavigate: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.selectedChain.id, 'ethereum');
  });

  testWidgets('scanned EIP-681 ERC20 uint256 uses token decimals', (
    tester,
  ) async {
    const recipient = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    const tokenContract = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithToken(tokenContract),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: _ethereum),
          ),
        ],
        child: _scanApp(
          const ScanPage(
            initialScanValue:
                'ethereum:$tokenContract@1/transfer'
                '?address=$recipient&uint256=1000000',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  test('address parser keeps known extended QR parameters', () {
    final parsed = parseWalletAddress(
      'ethereum:0x9858effd232b4033e47d90003d41ec34ecaeda94@56'
      '?decimal=18'
      '&symbol=USDC'
      '&token=0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
      '&contractAddress=0x2222222222222222222222222222222222222222'
      '&chainName=BNB%20Smart%20Chain'
      '&memo=Invoice%20123'
      '&label=Wallet%201'
      '&ignored=value',
    );

    expect(parsed?.address, '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(parsed?.decimal, '18');
    expect(parsed?.symbol, 'USDC');
    expect(parsed?.token, '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48');
    expect(
      parsed?.contractAddress,
      '0x2222222222222222222222222222222222222222',
    );
    expect(parsed?.chainName, 'BNB Smart Chain');
    expect(parsed?.memo, 'Invoice 123');
    expect(parsed?.label, 'Wallet 1');
  });

  testWidgets('scanned address fills transfer draft', (tester) async {
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(
          _FakeChainRepository(selectedChain: _ethereum),
        ),
      ],
    );
    addTearDown(container.dispose);
    const address = '0x9858effd232b4033e47d90003d41ec34ecaeda94';

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _scanApp(
          const ScanPage(initialScanValue: address, autoNavigate: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      container.read(transferDraftControllerProvider).prefilledRecipient,
      address,
    );
  });

  testWidgets('scanned Bitcoin address selects the Bitcoin chain', (
    tester,
  ) async {
    final repository = _FakeChainRepository(selectedChain: _ethereum);
    const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chainRepositoryProvider.overrideWithValue(repository)],
        child: _scanApp(
          const ScanPage(initialScanValue: address, autoNavigate: false),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.selectedChain.id, 'bitcoin-mainnet');
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ScanPage)),
      ).read(transferDraftControllerProvider).prefilledRecipient,
      address,
    );
  });

  testWidgets(
    'scanned Bitcoin testnet address selects a testnet Bitcoin chain',
    (tester) async {
      final repository = _FakeChainRepository(
        selectedChain: _ethereum,
        chains: [...defaultChains, _bitcoinTestnet],
      );
      const address = 'tb1qxmt9xgewg6mxc4mvnzvrzu4f2v0gy782fydg0w';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [chainRepositoryProvider.overrideWithValue(repository)],
          child: _scanApp(
            const ScanPage(initialScanValue: address, autoNavigate: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.selectedChain.id, 'bitcoin-testnet');
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ScanPage)),
        ).read(transferDraftControllerProvider).prefilledRecipient,
        address,
      );
    },
  );

  testWidgets(
    'scanned Bitcoin amount URI opens transfer with amount prefilled',
    (tester) async {
      final repository = _FakeChainRepository(selectedChain: _ethereum);
      const recipient = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetPortfolioProvider.overrideWith(
              (ref) async => _bitcoinPortfolio(),
            ),
            assetPortfolioRequestProvider.overrideWithValue(
              Future.value(_bitcoinAssetPortfolioRequest),
            ),
            chainRepositoryProvider.overrideWithValue(repository),
          ],
          child: _scanApp(
            const ScanPage(initialScanValue: 'bitcoin:$recipient?amount=0.001'),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.selectedChain.id, 'bitcoin-mainnet');
      expect(find.byType(TransferPage), findsOneWidget);
      expect(find.text(recipient), findsOneWidget);
      expect(find.widgetWithText(TextField, '金额'), findsOneWidget);
      expect(find.text('0.001'), findsOneWidget);
    },
  );

  testWidgets('scanned Bitcoin value URI falls back to transfer amount', (
    tester,
  ) async {
    final repository = _FakeChainRepository(selectedChain: _ethereum);
    const recipient = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _bitcoinPortfolio(),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_bitcoinAssetPortfolioRequest),
          ),
          chainRepositoryProvider.overrideWithValue(repository),
        ],
        child: _scanApp(
          const ScanPage(initialScanValue: 'bitcoin:$recipient?value=0.002'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.selectedChain.id, 'bitcoin-mainnet');
    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text(recipient), findsOneWidget);
    expect(find.widgetWithText(TextField, '金额'), findsOneWidget);
    expect(find.text('0.002'), findsOneWidget);
  });

  testWidgets('scanned token QR opens transfer with the token selected', (
    tester,
  ) async {
    const recipient = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
    const tokenContract = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithToken(tokenContract),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: _ethereum),
          ),
        ],
        child: _scanApp(
          const ScanPage(
            initialScanValue:
                'ethereum:$recipient@1?contractAddress=$tokenContract',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TransferPage), findsOneWidget);
    final selector = find.byKey(const Key('transferAssetSelector'));
    expect(
      find.descendant(of: selector, matching: find.text('USDC')),
      findsOneWidget,
    );
    expect(find.text(recipient), findsOneWidget);
  });

  testWidgets('scanned QR amount opens transfer with the amount prefilled', (
    tester,
  ) async {
    await _expectScannedAmountPrefillsTransfer(
      tester,
      queryParameter: 'amount=8.5',
      expectedAmount: '8.5',
    );
  });

  testWidgets('scanned EIP-681 value is converted from wei', (tester) async {
    await _expectScannedAmountPrefillsTransfer(
      tester,
      queryParameter: 'value=8',
      expectedAmount: '0.000000000000000008',
    );
  });

  testWidgets('scanned QR memo opens transfer with memo prefilled', (
    tester,
  ) async {
    const recipient = '0x9858effd232b4033e47d90003d41ec34ecaeda94';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithToken('0xunused'),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: _ethereum),
          ),
        ],
        child: _scanApp(
          const ScanPage(
            initialScanValue: 'ethereum:$recipient@1?memo=Invoice%20123',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TransferPage), findsOneWidget);
    expect(find.text(recipient), findsOneWidget);
    expect(find.text('Invoice 123'), findsOneWidget);
  });

  testWidgets('invalid scan displays localized error', (tester) async {
    await tester.pumpWidget(
      _scanApp(
        const ScanPage(initialScanValue: 'not an address', autoNavigate: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('二维码内容不是有效地址'), findsOneWidget);
  });

  group('English camera error localization', () {
    setUp(() async {
      await LocaleSettings.setLocale(AppLocale.en);
    });

    tearDown(() async {
      await LocaleSettings.setLocale(AppLocale.zh);
    });

    testWidgets('camera permission errors use localized scanner copy', (
      tester,
    ) async {
      final originalPlatform = MobileScannerPlatform.instance;
      final platform = _PermissionDeniedScannerPlatform();
      MobileScannerPlatform.instance = platform;
      addTearDown(() async {
        MobileScannerPlatform.instance = originalPlatform;
        await platform.close();
      });

      await tester.pumpWidget(_scanApp(const ScanPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('Camera permission is required to scan QR codes.'),
        findsOneWidget,
      );
      _expectNoVisibleHanText(tester);
    });
  });
}

Future<void> _expectScannedAmountPrefillsTransfer(
  WidgetTester tester, {
  required String queryParameter,
  required String expectedAmount,
}) async {
  const recipient = '0x9858effd232b4033e47d90003d41ec34ecaeda94';

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assetPortfolioProvider.overrideWith(
          (ref) async => _portfolioWithToken('0xunused'),
        ),
        assetPortfolioRequestProvider.overrideWithValue(
          Future.value(_assetPortfolioRequest),
        ),
        chainRepositoryProvider.overrideWithValue(
          _FakeChainRepository(selectedChain: _ethereum),
        ),
      ],
      child: _scanApp(
        ScanPage(initialScanValue: 'ethereum:$recipient@1?$queryParameter'),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();

  expect(find.byType(TransferPage), findsOneWidget);
  expect(find.text(recipient), findsOneWidget);
  expect(find.widgetWithText(TextField, '金额'), findsOneWidget);
  expect(find.text(expectedAmount), findsOneWidget);
}

final class _PermissionDeniedScannerPlatform extends MobileScannerPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<BarcodeCapture?> _barcodesController =
      StreamController<BarcodeCapture?>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodesController.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream<TorchState>.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream<double>.empty();

  @override
  Widget buildCameraView() => const SizedBox.shrink();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  Future<void> close() async {
    await _barcodesController.close();
  }
}

Widget _scanApp(Widget home) {
  return TranslationProvider(
    child: MaterialApp(theme: buildAppTheme(), home: home),
  );
}

AssetPortfolio _portfolioWithToken(String tokenContract) {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: _ethereum.chainId,
      token: TokenInfo(
        chainId: _ethereum.chainId,
        contractAddress: null,
        symbol: _ethereum.symbol,
        name: _ethereum.name,
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: '1000000000000000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
    ),
    AssetBalance(
      chainId: _ethereum.chainId,
      token: TokenInfo(
        chainId: _ethereum.chainId,
        contractAddress: tokenContract,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.userAdded,
        isHidden: false,
      ),
      balance: '10000000',
      formattedBalance: '10.0000',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

AssetPortfolio _bitcoinPortfolio() {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: _bitcoin.chainId,
      token: TokenInfo(
        chainId: _bitcoin.chainId,
        contractAddress: null,
        symbol: _bitcoin.symbol,
        name: _bitcoin.name,
        decimals: 8,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: '100000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

final _ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
final _bitcoin = defaultChains.firstWhere(
  (chain) => chain.id == 'bitcoin-mainnet',
);
final _assetPortfolioRequest = AssetPortfolioRequest(
  account: WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  ),
  chain: _ethereum,
  rpcNode: RpcNode(
    id: 'ethereum-default',
    chainId: _ethereum.chainId,
    name: 'Ethereum Default',
    url: _ethereum.rpcUrls.first,
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);
final _bitcoinAssetPortfolioRequest = AssetPortfolioRequest(
  account: WalletAccount(
    id: 'wallet-btc',
    name: 'Bitcoin Wallet',
    evmAddress: '',
    solanaAddress: '',
    btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  ),
  chain: _bitcoin,
  rpcNode: RpcNode(
    id: 'bitcoin-default',
    chainId: _bitcoin.chainId,
    name: 'Bitcoin Default',
    url: _bitcoin.rpcUrls.first,
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);

void _expectNoVisibleHanText(WidgetTester tester) {
  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .where((widget) => widget.data != null)
      .map((widget) => widget.data!)
      .toList(growable: false);
  for (final text in visibleTexts) {
    expect(
      text,
      isNot(contains(RegExp(r'[\u3400-\u9fff]'))),
      reason: 'Visible text should be localized to English: $text',
    );
  }
}

final class _FakeChainRepository implements ChainRepository {
  _FakeChainRepository({required this.selectedChain, List<ChainConfig>? chains})
    : chains = chains ?? defaultChains;

  ChainConfig selectedChain;
  final List<ChainConfig> chains;

  @override
  Future<List<ChainConfig>> getChains() async => chains;

  @override
  Future<ChainConfig> getSelectedChain() async => selectedChain;

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChain = chains.firstWhere((chain) => chain.id == chainId);
    return selectedChain;
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
}

const _bitcoinTestnet = ChainConfig(
  id: 'bitcoin-testnet',
  chainType: ChainType.bitcoin,
  name: 'Bitcoin Testnet',
  chainId: 'bitcoin-testnet',
  symbol: 'TBTC',
  rpcUrls: ['https://blockstream.info/testnet/api'],
  blockExplorerUrl: 'https://blockstream.info/testnet',
  isTestnet: true,
);
