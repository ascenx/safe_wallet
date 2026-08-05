import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/wallet/application/receive_qr_image_saver.dart';
import 'package:safe_wallet/features/wallet/application/receive_qr_image_saver_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/receive_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('receive action buttons use compact horizontal padding', (
    tester,
  ) async {
    await tester.pumpWidget(_receiveApp(account: _account()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    for (final key in const [
      Key('editReceiveAmountButton'),
      Key('saveReceiveAddressQrButton'),
      Key('copyReceiveAddressButton'),
    ]) {
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
      );
      expect(
        button.style?.padding?.resolve(<WidgetState>{}),
        const EdgeInsets.symmetric(horizontal: 8),
      );
    }
  });

  testWidgets('receive QR displays selected chain address and copies it', (
    tester,
  ) async {
    final account = _account();
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

    await tester.pumpWidget(_receiveApp(account: account));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Main Wallet - Ethereum'), findsOneWidget);
    expect(find.text('0x98...eda94'), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    final addressText = _textWithPlainText(tester, account.evmAddress);
    _expectHighlightedAddress(
      addressText.textSpan! as TextSpan,
      account.evmAddress,
    );
    expect(find.byKey(const Key('addressQrCard')), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, startsWith('ethereum:${account.evmAddress}@1?'));
    final qrParameters = Uri.parse(qr.semanticsLabel).queryParameters;
    expect(qrParameters['decimal'], '18');
    expect(qrParameters['symbol'], 'ETH');
    expect(qrParameters['chainName'], 'Ethereum');
    expect(qrParameters['label'], 'Main Wallet');
    expect(
      find.byKey(const Key('receiveAddressQrExportContent')),
      findsOneWidget,
    );
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('复制地址'), findsNothing);
    expect(find.text('复制'), findsOneWidget);

    final saveButton = find.byKey(const Key('saveReceiveAddressQrButton'));
    final copyButton = find.byKey(const Key('copyReceiveAddressButton'));
    expect(saveButton, findsOneWidget);
    expect(copyButton, findsOneWidget);
    expect(
      tester.getTopLeft(saveButton).dx,
      lessThan(tester.getTopLeft(copyButton).dx),
    );

    await tester.tap(find.byKey(const Key('copyReceiveAddressButton')));
    await tester.pump();

    expect(copiedText, account.evmAddress);
    expect(find.text('地址已复制'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('saving receive QR writes a PNG for wallet chain and address', (
    tester,
  ) async {
    final account = _account();
    final saver = _FakeReceiveQrImageSaver();

    await tester.pumpWidget(
      _receiveApp(account: account, receiveQrImageSaver: saver),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('saveReceiveAddressQrButton')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(saver.saveCallCount, 1);
    expect(saver.savedBytes, isNotNull);
    expect(saver.savedBytes!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(
      saver.savedFileName,
      matches(RegExp(r'^safe-wallet-ethereum-receive-\d+\.png$')),
    );
    expect(find.text('二维码已保存到相册'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('receive QR can include and remove a requested amount', (
    tester,
  ) async {
    final account = _account();
    final bnbChain = defaultChains.firstWhere(
      (chain) => chain.id == 'bnb-smart-chain',
    );

    await tester.pumpWidget(
      _receiveApp(
        account: account,
        selectedChain: bnbChain,
        portfolio: _portfolioForChain(bnbChain, priceUsd: 600),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final amountButton = find.byKey(const Key('editReceiveAmountButton'));
    final saveButton = find.byKey(const Key('saveReceiveAddressQrButton'));
    expect(amountButton, findsOneWidget);
    expect(saveButton, findsOneWidget);
    expect(find.text('数量'), findsOneWidget);
    expect(
      tester.getTopLeft(amountButton).dx,
      lessThan(tester.getTopLeft(saveButton).dx),
    );

    await tester.tap(amountButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('请输入数量'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text(r'8 BNB 约等于 $4,800.00 USD'), findsOneWidget);
    final qrWithAmount = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(
      Uri.parse(qrWithAmount.semanticsLabel).queryParameters['amount'],
      '8',
    );

    await tester.tap(find.byKey(const Key('removeReceiveAmountButton')));
    await tester.pumpAndSettle();

    expect(find.text(r'8 BNB 约等于 $4,800.00 USD'), findsNothing);
    final qrWithoutAmount = tester.widget<QrImageView>(
      find.byType(QrImageView),
    );
    expect(
      Uri.parse(qrWithoutAmount.semanticsLabel).queryParameters['amount'],
      isNull,
    );
  });

  testWidgets('receive QR uses Bitcoin address and amount URI', (tester) async {
    final account = _account();
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );

    await tester.pumpWidget(
      _receiveApp(
        account: account,
        selectedChain: bitcoin,
        portfolio: _portfolioForChain(bitcoin, priceUsd: 60000),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Main Wallet - Bitcoin'), findsOneWidget);
    expect(find.text(account.btcAddress), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.semanticsLabel, account.btcAddress);

    await tester.tap(find.byKey(const Key('editReceiveAmountButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0.001');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text(r'0.001 BTC 约等于 $60.00 USD'), findsOneWidget);
    final qrWithAmount = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qrWithAmount.semanticsLabel, startsWith('bitcoin:'));
    expect(
      Uri.parse(qrWithAmount.semanticsLabel).queryParameters['amount'],
      '0.001',
    );
  });

  testWidgets('receive QR is hidden when wallet lacks selected chain address', (
    tester,
  ) async {
    final account = _bitcoinOnlyAccount();
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );

    await tester.pumpWidget(
      _receiveApp(
        account: account,
        selectedChain: ethereum,
        portfolio: AssetPortfolio.empty(account: account),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('当前钱包没有当前链地址'), findsOneWidget);
    expect(find.byKey(const Key('addressQrCard')), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
  });
}

Widget _receiveApp({
  required WalletAccount account,
  ChainConfig? selectedChain,
  AssetPortfolio? portfolio,
  ReceiveQrImageSaver? receiveQrImageSaver,
}) {
  return ProviderScope(
    overrides: [
      chainRepositoryProvider.overrideWithValue(
        _FakeChainRepository(selectedChain ?? defaultChains.first),
      ),
      if (portfolio != null)
        assetPortfolioProvider.overrideWith((ref) async => portfolio),
      walletRepositoryProvider.overrideWithValue(
        _FakeWalletRepository(account),
      ),
      if (receiveQrImageSaver != null)
        receiveQrImageSaverProvider.overrideWithValue(receiveQrImageSaver),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: const ReceivePage()),
    ),
  );
}

AssetPortfolio _portfolioForChain(
  ChainConfig chain, {
  required double priceUsd,
}) {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: chain.chainId,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: switch (chain.chainType) {
          ChainType.evm => 18,
          ChainType.bitcoin => 8,
          ChainType.tron => 6,
          ChainType.solana => 9,
          ChainType.sui => 9,
        },
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: '1000000000000000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
      priceUsd: priceUsd,
    ),
  ]);
}

WalletAccount _account() {
  return WalletAccount(
    id: 'wallet-1',
    name: 'Main Wallet',
    evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
    solanaAddress: '11111111111111111111111111111111',
    btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  );
}

WalletAccount _bitcoinOnlyAccount() {
  return WalletAccount(
    id: 'wallet-btc',
    name: 'BTC Wallet',
    evmAddress: '',
    solanaAddress: '',
    btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
    source: WalletAccountSource.privateKey,
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  );
}

Text _textWithPlainText(WidgetTester tester, String plainText) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .singleWhere(
        (widget) =>
            widget.data == plainText ||
            widget.textSpan?.toPlainText() == plainText,
      );
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

final class _FakeReceiveQrImageSaver implements ReceiveQrImageSaver {
  int saveCallCount = 0;
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<void> save(Uint8List bytes, {required String fileName}) async {
    saveCallCount += 1;
    savedBytes = bytes;
    savedFileName = fileName;
  }
}

final class _FakeChainRepository implements ChainRepository {
  const _FakeChainRepository(this.selectedChain);

  final ChainConfig selectedChain;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

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
  Future<ChainConfig> getSelectedChain() async {
    return selectedChain;
  }

  @override
  Future<ChainConfig> selectChain(String chainId) {
    throw UnimplementedError();
  }
}

final class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository(this.account);

  final WalletAccount account;

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
  Future<List<WalletAccount>> getWallets() async => [account];

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
