import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/address_book_repository.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_fee_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/transfer/presentation/transfer_page.dart';
import 'package:safe_wallet/features/transfer/presentation/scan_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('recipient scan returns to the form and clears stale errors', (
    tester,
  ) async {
    await _pumpRecipientScanForm(tester);
    final originalState = tester.state(find.byType(TransferPage));
    await tester.enterText(
      find.widgetWithText(TextField, '收款地址'),
      'not-an-address',
    );
    await tester.enterText(find.widgetWithText(TextField, '金额'), '0.1');
    await tester.enterText(
      find.widgetWithText(TextField, '备注 / Tag'),
      'My memo',
    );
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('收款地址格式无效'), findsOneWidget);

    await tester.tap(find.byTooltip('扫码'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsOneWidget);
    _captureRecipientScan(
      tester,
      'ethereum:$_friendAddress@1?amount=99&memo=QR%20memo',
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScanPage), findsNothing);
    expect(tester.state(find.byType(TransferPage)), same(originalState));
    expect(find.text(_friendAddress), findsOneWidget);
    expect(find.text('收款地址格式无效'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '金额'))
          .controller!
          .text,
      '0.1',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '备注 / Tag'))
          .controller!
          .text,
      'My memo',
    );
  });

  testWidgets('recipient scan cancellation preserves existing form values', (
    tester,
  ) async {
    await _pumpRecipientScanForm(tester);
    await tester.enterText(
      find.widgetWithText(TextField, '收款地址'),
      _friendAddress,
    );
    await tester.enterText(find.widgetWithText(TextField, '金额'), '0.25');
    await tester.tap(find.byTooltip('扫码'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(_friendAddress), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '金额'))
          .controller!
          .text,
      '0.25',
    );
  });

  testWidgets('recipient scan rejects invalid and mismatched QR then retries', (
    tester,
  ) async {
    await _pumpRecipientScanForm(tester);
    await tester.tap(find.byTooltip('扫码'));
    await tester.pumpAndSettle();

    _captureRecipientScan(tester, 'not-an-address');
    await tester.pumpAndSettle();
    expect(find.text('二维码内容不是有效地址'), findsOneWidget);

    for (final raw in [
      'bitcoin:$_bitcoinFriendAddress',
      'ethereum:$_friendAddress@56',
    ]) {
      _captureRecipientScan(tester, raw);
      await tester.pumpAndSettle();
      expect(find.byType(ScanPage), findsOneWidget);
      expect(find.text('收款地址格式无效'), findsOneWidget);
    }

    _captureRecipientScan(tester, _friendAddress);
    await tester.pumpAndSettle();
    expect(find.byType(ScanPage), findsNothing);
    expect(find.text(_friendAddress), findsOneWidget);
  });

  for (final (chainId, address, expectedAddress) in [
    ('ethereum', _friendAddress, _friendAddress),
    (
      'solana-mainnet',
      '11111111111111111111111111111111',
      '11111111111111111111111111111111',
    ),
    ('bitcoin-mainnet', _bitcoinFriendAddress, _bitcoinFriendAddress),
    (
      'tron-mainnet',
      'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8',
      'TJRabPrwbZy45sbavfcjinPJC18kjpRTv8',
    ),
    (
      'sui-mainnet',
      '0x2',
      '0x0000000000000000000000000000000000000000000000000000000000000002',
    ),
  ]) {
    testWidgets('recipient scan accepts a raw $chainId address', (
      tester,
    ) async {
      final chain = defaultChains.firstWhere((chain) => chain.id == chainId);
      await _pumpRecipientScanForm(tester, chain: chain);
      await tester.tap(find.byTooltip('扫码'));
      await tester.pumpAndSettle();
      _captureRecipientScan(tester, address);
      await tester.pumpAndSettle();

      expect(find.byType(ScanPage), findsNothing);
      expect(find.text(expectedAddress), findsOneWidget);
    });
  }

  testWidgets('recipient scan rejects a Bitcoin address on the wrong network', (
    tester,
  ) async {
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    await _pumpRecipientScanForm(tester, chain: bitcoin);
    await tester.tap(find.byTooltip('扫码'));
    await tester.pumpAndSettle();
    _captureRecipientScan(tester, 'tb1qxmt9xgewg6mxc4mvnzvrzu4f2v0gy782fydg0w');
    await tester.pumpAndSettle();

    expect(find.byType(ScanPage), findsOneWidget);
    expect(find.text('收款地址格式无效'), findsOneWidget);
    _captureRecipientScan(tester, _bitcoinFriendAddress);
    await tester.pumpAndSettle();
    expect(find.text(_bitcoinFriendAddress), findsOneWidget);
  });

  testWidgets('native Max reserves the maximum EVM network fee', (
    tester,
  ) async {
    final feeService = _FixedEvmFeeService(
      EvmFeeEstimate.eip1559(
        gasLimit: BigInt.from(21000),
        maxFeePerGasWei: BigInt.from(30000000000),
        maxPriorityFeePerGasWei: BigInt.from(2000000000),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async => _portfolio()),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          evmFeeServiceProvider.overrideWithValue(feeService),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '收款地址'),
      _friendAddress,
    );
    await tester.tap(find.text('最大'));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(
      find.widgetWithText(TextField, '金额'),
    );
    expect(amountField.controller!.text, '0.99937');
    expect(feeService.amounts, [
      BigInt.one,
      BigInt.parse('999370000000000000'),
    ]);
  });

  testWidgets('token Max uses the exact raw balance instead of display text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithExactTokenBalance(),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('最大'));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(
      find.widgetWithText(TextField, '金额'),
    );
    expect(amountField.controller!.text, '1.234567890123456789');
  });

  testWidgets('Bitcoin Max requests a sweep quote and reserves its fee', (
    tester,
  ) async {
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    final feeService = _FixedBitcoinFeeService(
      BitcoinFeeEstimate(
        satoshis: BigInt.from(1780),
        satsPerVbyte: 10,
        transactionVbytes: 178,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolio(chain: bitcoin),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequestFor(bitcoin)),
          ),
          bitcoinFeeServiceProvider.overrideWithValue(feeService),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '收款地址'),
      _bitcoinFriendAddress,
    );
    await tester.tap(find.text('最大'));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(
      find.widgetWithText(TextField, '金额'),
    );
    expect(amountField.controller!.text, '0.9999822');
    expect(feeService.amounts, [BigInt.from(100000000), BigInt.from(99998220)]);
    expect(feeService.sweeps, [isTrue, isTrue]);
  });

  testWidgets('asset selector opens a balance-descending bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithSelectableAssets(),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.byKey(const Key('transferAssetSelector')));
    await tester.pumpAndSettle();

    final high = find.byKey(const ValueKey('transferAssetOption:1:0xhigh'));
    final medium = find.byKey(const ValueKey('transferAssetOption:1:0xmedium'));
    final zero = find.byKey(const ValueKey('transferAssetOption:1:0xzero'));
    expect(find.text('隐藏 0 余额资产'), findsOneWidget);
    expect(high, findsOneWidget);
    expect(medium, findsOneWidget);
    expect(zero, findsOneWidget);
    expect(tester.getTopLeft(high).dy, lessThan(tester.getTopLeft(medium).dy));
    expect(tester.getTopLeft(medium).dy, lessThan(tester.getTopLeft(zero).dy));
    final selectedSurface = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('transferAssetSelectionSurface:1:0xmedium')),
    );
    final selectedDecoration = selectedSurface.decoration! as BoxDecoration;
    expect(selectedDecoration.color, AppColors.primarySoft);
    expect((selectedDecoration.border! as Border).top.color, AppColors.primary);
    expect(
      find.descendant(
        of: medium,
        matching: find.byIcon(AppIcons.checkCircleFilled),
      ),
      findsNothing,
    );
  });

  testWidgets('asset sheet can hide zero balances and select an asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithSelectableAssets(),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transferAssetSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transferHideZeroBalanceSwitch')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('transferAssetOption:1:0xzero')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('transferAssetOption:1:0xmedium')),
    );
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('transferAssetSelector'));
    expect(
      find.descendant(of: selector, matching: find.text('MID')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selector, matching: find.text('2.0000')),
      findsOneWidget,
    );
  });

  testWidgets('selecting another asset clears the entered amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolioWithSelectableAssets(),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = find.widgetWithText(TextField, '金额');
    await tester.enterText(amountField, '1.25');
    await tester.tap(find.byKey(const Key('transferAssetSelector')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('transferAssetOption:1:0xhigh')),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(amountField).controller!.text, isEmpty);
  });

  testWidgets('optional memo tag field explains when to leave it blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async => _portfolio()),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('备注 / Tag'), findsOneWidget);
    expect(find.text('可选。仅在收款方要求时填写。'), findsOneWidget);
  });

  testWidgets('selecting a contact clears a stale recipient error', (
    tester,
  ) async {
    final repository = _FakeAddressBookRepository([
      AddressBookContact(
        id: 'contact-1',
        name: 'Ethereum Friend',
        address: _friendAddress,
        chainType: ChainType.evm,
        note: null,
        createdAt: _now,
        updatedAt: _now,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async => _portfolio()),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          addressBookRepositoryProvider.overrideWithValue(repository),
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository([_assetPortfolioRequest.account]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '收款地址'),
      'not-an-address',
    );
    await tester.enterText(find.widgetWithText(TextField, '金额'), '0.1');
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('收款地址格式无效'), findsOneWidget);

    await tester.tap(find.byTooltip('选择联系人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ethereum Friend'));
    await tester.pumpAndSettle();

    expect(find.text('收款地址格式无效'), findsNothing);
    expect(find.text(_friendAddress), findsOneWidget);
  });

  testWidgets('recipient picker selects another wallet on the same chain', (
    tester,
  ) async {
    const otherWalletAddress = '0x3333333333333333333333333333333333333333';
    final wallets = [
      _assetPortfolioRequest.account,
      WalletAccount(
        id: 'wallet-2',
        name: 'Other Wallet',
        evmAddress: otherWalletAddress,
        solanaAddress: '22222222222222222222222222222222',
        createdAt: _now,
        updatedAt: _now,
      ),
      WalletAccount(
        id: 'wallet-3',
        name: 'Bitcoin Only',
        evmAddress: '',
        solanaAddress: '',
        btcAddress: _bitcoinFriendAddress,
        createdAt: _now,
        updatedAt: _now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async => _portfolio()),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          addressBookRepositoryProvider.overrideWithValue(
            _FakeAddressBookRepository([
              AddressBookContact(
                id: 'contact-1',
                name: 'Ethereum Friend',
                address: _friendAddress,
                chainType: ChainType.evm,
                note: null,
                createdAt: _now,
                updatedAt: _now,
              ),
            ]),
          ),
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository(wallets),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择联系人'));
    await tester.pumpAndSettle();

    expect(find.text('其他钱包'), findsOneWidget);
    expect(find.text('地址簿联系人'), findsOneWidget);
    expect(find.text('Other Wallet'), findsOneWidget);
    expect(find.text('Ethereum Friend'), findsOneWidget);
    expect(find.text('Wallet 1'), findsNothing);
    expect(find.text('Bitcoin Only'), findsNothing);
    final walletAddressText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere(
          (widget) => widget.text.toPlainText().startsWith('0x33333333'),
        )
        .text
        .toPlainText();
    expect(walletAddressText, '0x3333333333…333333333333');

    await tester.tap(find.text('Other Wallet'));
    await tester.pumpAndSettle();

    expect(find.text(otherWalletAddress), findsOneWidget);
  });

  testWidgets('recipient picker reloads wallets after it is reopened', (
    tester,
  ) async {
    const existingAddress = '0x3333333333333333333333333333333333333333';
    const importedAddress = '0x4444444444444444444444444444444444444444';
    final walletRepository = _FakeWalletRepository([
      _assetPortfolioRequest.account,
      WalletAccount(
        id: 'wallet-2',
        name: 'Old Wallet Name',
        evmAddress: existingAddress,
        solanaAddress: '22222222222222222222222222222222',
        createdAt: _now,
        updatedAt: _now,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async => _portfolio()),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequest),
          ),
          addressBookRepositoryProvider.overrideWithValue(
            _FakeAddressBookRepository(const []),
          ),
          walletRepositoryProvider.overrideWithValue(walletRepository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择联系人'));
    await tester.pumpAndSettle();
    expect(find.text('Old Wallet Name'), findsOneWidget);
    await tester.tap(find.text('Old Wallet Name'));
    await tester.pumpAndSettle();

    walletRepository.replaceWallets([
      _assetPortfolioRequest.account,
      WalletAccount(
        id: 'wallet-2',
        name: 'Renamed Wallet',
        evmAddress: existingAddress,
        solanaAddress: '22222222222222222222222222222222',
        createdAt: _now,
        updatedAt: _now,
      ),
      WalletAccount(
        id: 'wallet-3',
        name: 'Imported Wallet',
        evmAddress: importedAddress,
        solanaAddress: '33333333333333333333333333333333',
        createdAt: _now,
        updatedAt: _now,
      ),
    ]);

    await tester.tap(find.byTooltip('选择联系人'));
    await tester.pumpAndSettle();

    expect(find.text('Old Wallet Name'), findsNothing);
    expect(find.text('Renamed Wallet'), findsOneWidget);
    expect(find.text('Imported Wallet'), findsOneWidget);
  });

  testWidgets('Bitcoin transfer selects Bitcoin address book contacts', (
    tester,
  ) async {
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    final repository = _FakeAddressBookRepository([
      AddressBookContact(
        id: 'contact-evm',
        name: 'Ethereum Friend',
        address: _friendAddress,
        chainType: ChainType.evm,
        note: null,
        createdAt: _now,
        updatedAt: _now,
      ),
      AddressBookContact(
        id: 'contact-bitcoin',
        name: 'Bitcoin Friend',
        address: _bitcoinFriendAddress,
        chainType: ChainType.bitcoin,
        note: null,
        createdAt: _now,
        updatedAt: _now,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith(
            (ref) async => _portfolio(chain: bitcoin),
          ),
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(_assetPortfolioRequestFor(bitcoin)),
          ),
          addressBookRepositoryProvider.overrideWithValue(repository),
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository([_assetPortfolioRequestFor(bitcoin).account]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择联系人'));
    await tester.pumpAndSettle();

    expect(find.text('Bitcoin Friend'), findsOneWidget);
    expect(find.text('Ethereum Friend'), findsNothing);

    await tester.tap(find.text('Bitcoin Friend'));
    await tester.pumpAndSettle();

    expect(find.text(_bitcoinFriendAddress), findsOneWidget);
  });
}

Future<void> _pumpRecipientScanForm(
  WidgetTester tester, {
  ChainConfig? chain,
}) async {
  final originalPlatform = MobileScannerPlatform.instance;
  MobileScannerPlatform.instance = _RecipientScannerPlatform();
  addTearDown(() => MobileScannerPlatform.instance = originalPlatform);
  final request = chain == null
      ? _assetPortfolioRequest
      : _assetPortfolioRequestFor(chain);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assetPortfolioProvider.overrideWith(
          (ref) async => _portfolio(chain: request.chain),
        ),
        assetPortfolioRequestProvider.overrideWithValue(Future.value(request)),
      ],
      child: TranslationProvider(
        child: MaterialApp(theme: buildAppTheme(), home: const TransferPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _captureRecipientScan(WidgetTester tester, String rawValue) {
  tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
    BarcodeCapture(barcodes: [Barcode(rawValue: rawValue)]),
  );
}

final class _RecipientScannerPlatform extends MobileScannerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const SizedBox.shrink();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

AssetPortfolio _portfolio({ChainConfig? chain}) {
  final selectedChain = chain ?? _ethereum;
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: selectedChain.chainId,
      token: TokenInfo(
        chainId: selectedChain.chainId,
        contractAddress: null,
        symbol: selectedChain.symbol,
        name: selectedChain.name,
        decimals: switch (selectedChain.chainType) {
          ChainType.evm => 18,
          ChainType.bitcoin => 8,
          ChainType.tron => 6,
          ChainType.solana => 9,
          ChainType.sui => 9,
        },
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: selectedChain.chainType == ChainType.bitcoin
          ? '100000000'
          : '1000000000000000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

AssetPortfolio _portfolioWithSelectableAssets() {
  return AssetPortfolio.loaded([
    _selectableBalance(
      symbol: 'ZERO',
      contractAddress: '0xzero',
      rawBalance: '0',
      formattedBalance: '0.0000',
      fiatValue: r'$0.00',
      decimals: 8,
    ),
    _selectableBalance(
      symbol: 'MID',
      contractAddress: '0xmedium',
      rawBalance: '2000000',
      formattedBalance: '2.0000',
      fiatValue: r'$4.00',
      decimals: 6,
    ),
    _selectableBalance(
      symbol: 'HIGH',
      contractAddress: '0xhigh',
      rawBalance: '12500000000000000000',
      formattedBalance: '12.5000',
      fiatValue: r'$25.00',
      decimals: 18,
    ),
  ]);
}

AssetPortfolio _portfolioWithExactTokenBalance() {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: _ethereum.chainId,
      token: TokenInfo(
        chainId: _ethereum.chainId,
        contractAddress: '0x1111111111111111111111111111111111111111',
        symbol: 'EXACT',
        name: 'Exact Token',
        decimals: 18,
        source: TokenSource.userAdded,
        isHidden: false,
      ),
      balance: '1234567890123456789',
      formattedBalance: '1.23456',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

AssetBalance _selectableBalance({
  required String symbol,
  required String contractAddress,
  required String rawBalance,
  required String formattedBalance,
  required String fiatValue,
  required int decimals,
}) {
  return AssetBalance(
    chainId: _ethereum.chainId,
    token: TokenInfo(
      chainId: _ethereum.chainId,
      contractAddress: contractAddress,
      symbol: symbol,
      name: '$symbol Token',
      decimals: decimals,
      source: TokenSource.userAdded,
      isHidden: false,
    ),
    balance: rawBalance,
    formattedBalance: formattedBalance,
    fiatValue: fiatValue,
    status: AssetBalanceStatus.loaded,
  );
}

final _ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
final _now = DateTime.utc(2026, 6, 6, 12);
const _friendAddress = '0x2222222222222222222222222222222222222222';
const _bitcoinFriendAddress = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';

AssetPortfolioRequest _assetPortfolioRequestFor(ChainConfig chain) {
  return AssetPortfolioRequest(
    account: WalletAccount(
      id: 'wallet-1',
      name: 'Wallet 1',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '11111111111111111111111111111111',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: _now,
      updatedAt: _now,
    ),
    chain: chain,
    rpcNode: RpcNode(
      id: '${chain.id}-default',
      chainId: chain.chainId,
      name: '${chain.name} Default',
      url: chain.rpcUrls.first,
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    ),
  );
}

final _assetPortfolioRequest = AssetPortfolioRequest(
  account: WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: _now,
    updatedAt: _now,
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

final class _FakeAddressBookRepository implements AddressBookRepository {
  const _FakeAddressBookRepository(this.contacts);

  final List<AddressBookContact> contacts;

  @override
  Future<void> deleteContact(String contactId) {
    throw UnimplementedError();
  }

  @override
  Future<List<AddressBookContact>> listContacts() async {
    return List.unmodifiable(contacts);
  }

  @override
  Future<AddressBookContact> saveContact(AddressBookContact contact) {
    throw UnimplementedError();
  }
}

final class _FixedEvmFeeService implements EvmFeeService {
  _FixedEvmFeeService(this.estimate);

  final EvmFeeEstimate estimate;
  final List<BigInt> amounts = [];

  @override
  Future<EvmFeeEstimate> estimateTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required TransactionType transactionType,
    required BigInt amountInWei,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  }) async {
    amounts.add(amountInWei);
    return estimate;
  }
}

final class _FixedBitcoinFeeService implements BitcoinFeeService {
  _FixedBitcoinFeeService(this.estimate);

  final BitcoinFeeEstimate estimate;
  final List<BigInt> amounts = [];
  final List<bool> sweeps = [];

  @override
  Future<BitcoinFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt satoshis,
    bool sweep = false,
  }) async {
    amounts.add(satoshis);
    sweeps.add(sweep);
    return estimate;
  }
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository(List<WalletAccount> wallets)
    : _wallets = List.of(wallets);

  final List<WalletAccount> _wallets;

  void replaceWallets(List<WalletAccount> wallets) {
    _wallets
      ..clear()
      ..addAll(wallets);
  }

  @override
  Future<List<WalletAccount>> getWallets() async => List.unmodifiable(_wallets);

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

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
  }) {
    throw UnimplementedError();
  }
}
