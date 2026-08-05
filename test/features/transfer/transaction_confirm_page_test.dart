import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_confirm_controller.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_confirm_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('confirmation warns for a recipient with no transfer history', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.legacy(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      gasPriceWei: BigInt.from(10000000000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
          historicalRecipients: const [],
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.textContaining('这是一个从未转账过的新地址，请核对完整地址和收款网络。'), findsOneWidget);
  });

  testWidgets('confirmation warns for a lookalike historical recipient', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    const recipient = '0x123456aaaaaaaaaaaaaaaaaaaaaaaaaaaaabcdef';
    const historical = '0x123456bbbbbbbbbbbbbbbbbbbbbbbbbbbbabcdef';
    final request = _transferRequest(chain, toAddress: recipient);
    final feeEstimate = FeeEstimate.legacy(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      gasPriceWei: BigInt.from(10000000000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
          historicalRecipients: const [historical],
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('该地址与历史收款地址高度相似但并不相同，可能是地址投毒。相似历史地址：$historical'),
      findsOneWidget,
    );
  });

  testWidgets('EIP-1559 confirmation shows max and priority gas fees', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30000000000),
      maxPriorityFeePerGasWei: BigInt.from(2000000000),
      baseFeePerGasWei: BigInt.from(20000000000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('最大 Gas 费率'), findsOneWidget);
    expect(find.text('提交'), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsNothing);
    expect(find.text('30 Gwei'), findsOneWidget);
    expect(find.text('优先费率'), findsOneWidget);
    expect(find.text('2 Gwei'), findsOneWidget);
    expect(find.text('预计手续费'), findsOneWidget);
    expect(find.text('0.000462 ETH'), findsOneWidget);
    expect(find.text('最高手续费'), findsOneWidget);
    expect(find.text('0.00063 ETH'), findsOneWidget);
    expect(find.text('0.10063 ETH'), findsOneWidget);
    expect(find.text('Gas Price'), findsNothing);
  });

  testWidgets('fee row opens bottom sheet and selecting economy updates fee', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
      maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
      baseFeePerGasWei: BigInt.from(20) * BigInt.from(1000000000),
      options: [
        FeeOption(
          speed: FeeSpeed.economy,
          feeInBaseUnits: BigInt.from(420000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(20) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(1) * BigInt.from(1000000000),
        ),
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: BigInt.from(630000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
        ),
        FeeOption(
          speed: FeeSpeed.fast,
          feeInBaseUnits: BigInt.from(840000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(40) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(3) * BigInt.from(1000000000),
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeOption:economy')), findsOneWidget);
    expect(find.byKey(const Key('feeOption:standard')), findsOneWidget);
    expect(find.byKey(const Key('feeOption:fast')), findsOneWidget);
    expect(find.byKey(const Key('feeOption:custom')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feeOption:economy')));
    await tester.pumpAndSettle();

    expect(find.text('0.00042 ETH'), findsOneWidget);
    expect(find.text('20 Gwei'), findsOneWidget);
  });

  testWidgets('changing fee speed recalculates a native Max transfer amount', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final balance = BigInt.from(1000000000000000000);
    final standardFee = BigInt.from(630000000000000);
    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: '0x2222222222222222222222222222222222222222',
      amount: '0.99937',
      amountInBaseUnits: (balance - standardFee).toString(),
      tokenDecimals: 18,
      transactionType: TransactionType.nativeTransfer,
    );
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
      maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
      options: [
        FeeOption(
          speed: FeeSpeed.economy,
          feeInBaseUnits: BigInt.from(420000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(20) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(1) * BigInt.from(1000000000),
        ),
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: standardFee,
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
        ),
        FeeOption(
          speed: FeeSpeed.fast,
          feeInBaseUnits: BigInt.from(840000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(40) * BigInt.from(1000000000),
          maxPriorityFeePerGasWei: BigInt.from(3) * BigInt.from(1000000000),
        ),
      ],
    );
    final confirmation = const TransactionConfirmController().buildConfirmation(
      chain: chain,
      account: _account,
      request: request,
      feeEstimate: feeEstimate,
      availableBalanceInBaseUnits: balance,
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: confirmation,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeOption:fast')));
    await tester.pumpAndSettle();

    expect(find.text('0.99916'), findsOneWidget);
    expect(find.text('1 ETH'), findsOneWidget);
  });

  testWidgets('selected fee option uses background and border emphasis', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30000000000),
      maxPriorityFeePerGasWei: BigInt.from(2000000000),
      options: [
        FeeOption(
          speed: FeeSpeed.economy,
          feeInBaseUnits: BigInt.from(420000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(20000000000),
          maxPriorityFeePerGasWei: BigInt.from(1000000000),
        ),
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: BigInt.from(630000000000000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(30000000000),
          maxPriorityFeePerGasWei: BigInt.from(2000000000),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();

    AnimatedContainer surface(String speed) => tester.widget(
      find.descendant(
        of: find.byKey(Key('feeOption:$speed')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final standardDecoration = surface('standard').decoration! as BoxDecoration;
    final economyDecoration = surface('economy').decoration! as BoxDecoration;

    expect(standardDecoration.color, AppColors.primarySoft);
    expect(standardDecoration.border, Border.all(color: AppColors.primary));
    expect(economyDecoration.color, AppColors.surfaceSoft);
    expect(economyDecoration.border, Border.all(color: AppColors.border));
  });

  testWidgets('EIP-1559 custom sheet validates and applies Gwei fields', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
      maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
      baseFeePerGasWei: BigInt.from(20) * BigInt.from(1000000000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeOption:custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customMaxFeeGwei')), '1');
    await tester.enterText(find.byKey(const Key('customPriorityFeeGwei')), '2');
    await tester.tap(find.byKey(const Key('applyCustomFee')));
    await tester.pump();

    expect(find.text('最大费率不能低于优先费率'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customMaxFeeGwei')), '21');
    await tester.pump();
    expect(find.text('当前费率低于网络基础费用，交易可能长时间无法确认'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customMaxFeeGwei')), '40');
    await tester.tap(find.byKey(const Key('applyCustomFee')));
    await tester.pumpAndSettle();

    expect(find.text('40 Gwei'), findsOneWidget);
    expect(find.text('3 Gwei'), findsNothing);
    expect(find.text('2 Gwei'), findsOneWidget);
  });

  testWidgets('legacy confirmation shows gas price', (tester) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.legacy(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      gasPriceWei: BigInt.from(10000000000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('Gas Price'), findsOneWidget);
    expect(find.text('10 Gwei'), findsOneWidget);
    expect(find.text('0.00021 ETH'), findsOneWidget);
    expect(find.text('0.10021 ETH'), findsOneWidget);
    expect(find.text('最大 Gas 费率'), findsNothing);
    expect(find.text('优先费率'), findsNothing);
  });

  testWidgets('Solana confirmation shows SOL fee and total deduction', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: '11111111111111111111111111111111',
      amount: '0.1',
      amountInBaseUnits: '100000000',
      tokenDecimals: 9,
      transactionType: TransactionType.solTransfer,
    );
    final feeEstimate = FeeEstimate.solana(
      feeAssetSymbol: chain.symbol,
      lamports: BigInt.from(5000),
      recentBlockhash: 'recent-blockhash',
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _solanaAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _solanaAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('Solana Fee'), findsOneWidget);
    expect(find.text('0.000005 SOL'), findsOneWidget);
    expect(find.text('0.100005 SOL'), findsOneWidget);
    expect(find.text(_solanaAccount.solanaAddress), findsOneWidget);
  });

  testWidgets(
    'Solana custom total priority fee updates CU price and total fee',
    (tester) async {
      final chain = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      final request = TransactionRequest(
        chainId: chain.chainId,
        chainType: chain.chainType,
        assetSymbol: chain.symbol,
        toAddress: '11111111111111111111111111111111',
        amount: '0.1',
        amountInBaseUnits: '100000000',
        tokenDecimals: 9,
        transactionType: TransactionType.solTransfer,
      );
      final feeEstimate = FeeEstimate.solana(
        feeAssetSymbol: chain.symbol,
        lamports: BigInt.from(5000),
        recentBlockhash: 'recent-blockhash',
        computeUnitLimit: 220000,
        microLamportsPerComputeUnit: BigInt.from(2000),
        priorityFeeLamports: BigInt.from(440),
      );
      await tester.pumpWidget(
        _app(
          TransactionConfirmPage(
            chain: chain,
            rpcNode: _rpcNode(chain),
            account: _solanaAccount,
            request: request,
            feeEstimate: feeEstimate,
            confirmation: _confirmation(
              chain: chain,
              account: _solanaAccount,
              request: request,
              feeEstimate: feeEstimate,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feeOption:custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('customSolanaPriorityFee')),
        '0.00001',
      );
      await tester.tap(find.byKey(const Key('applyCustomFee')));
      await tester.pumpAndSettle();

      expect(find.text('0.000015001 SOL'), findsOneWidget);
      expect(find.text('0.000010001 SOL'), findsOneWidget);
    },
  );

  testWidgets(
    'Bitcoin confirmation shows Bitcoin fee model without gas fields',
    (tester) async {
      final chain = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      const recipient = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
      final request = TransactionRequest(
        chainId: chain.chainId,
        chainType: chain.chainType,
        assetSymbol: chain.symbol,
        toAddress: recipient,
        amount: '0.1',
        amountInBaseUnits: '10000000',
        tokenDecimals: 8,
        transactionType: TransactionType.bitcoinTransfer,
      );
      final feeEstimate = FeeEstimate.bitcoin(
        feeAssetSymbol: chain.symbol,
        satoshis: BigInt.from(1410),
      );

      await tester.pumpWidget(
        _app(
          TransactionConfirmPage(
            chain: chain,
            rpcNode: _rpcNode(chain),
            account: _bitcoinAccount,
            request: request,
            feeEstimate: feeEstimate,
            confirmation: _confirmation(
              chain: chain,
              account: _bitcoinAccount,
              request: request,
              feeEstimate: feeEstimate,
            ),
          ),
        ),
      );

      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Bitcoin 手续费'), findsOneWidget);
      expect(find.text('0.0000141 BTC'), findsOneWidget);
      expect(find.text('0.1000141 BTC'), findsOneWidget);
      expect(find.text(_bitcoinAccount.btcAddress), findsOneWidget);
      expect(find.text(recipient), findsOneWidget);
      expect(find.text('最大 Gas 费率'), findsNothing);
      expect(find.text('优先费率'), findsNothing);
      expect(find.text('Gas Price'), findsNothing);
    },
  );

  testWidgets('Bitcoin custom sat per vbyte updates confirmation', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      amount: '0.1',
      amountInBaseUnits: '10000000',
      tokenDecimals: 8,
      transactionType: TransactionType.bitcoinTransfer,
    );
    final feeEstimate = FeeEstimate.bitcoin(
      feeAssetSymbol: chain.symbol,
      satoshis: BigInt.from(1410),
      satsPerVbyte: 10,
      transactionVbytes: 141,
      confirmationBlocks: 3,
      options: [
        FeeOption(
          speed: FeeSpeed.economy,
          feeInBaseUnits: BigInt.from(705),
          satsPerVbyte: 5,
          transactionVbytes: 141,
          confirmationBlocks: 12,
        ),
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: BigInt.from(1410),
          satsPerVbyte: 10,
          transactionVbytes: 141,
          confirmationBlocks: 3,
        ),
        FeeOption(
          speed: FeeSpeed.fast,
          feeInBaseUnits: BigInt.from(2820),
          satsPerVbyte: 20,
          transactionVbytes: 141,
          confirmationBlocks: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _bitcoinAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _bitcoinAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeOption:custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customBitcoinFeeRate')),
      '12.5',
    );
    await tester.tap(find.byKey(const Key('applyCustomFee')));
    await tester.pumpAndSettle();

    expect(find.text('0.00001763 BTC'), findsOneWidget);
    expect(find.text('12.5 sat/vB'), findsOneWidget);
    expect(find.text('预计确认'), findsOneWidget);
    expect(find.text('约 3 个区块'), findsOneWidget);
  });

  testWidgets('Tron confirmation shows localized TRX fee model', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'tron-mainnet',
    );
    const recipient = 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj';
    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: recipient,
      amount: '0.1',
      amountInBaseUnits: '100000',
      tokenDecimals: 6,
      transactionType: TransactionType.nativeTransfer,
    );
    final feeEstimate = FeeEstimate.tron(
      feeAssetSymbol: chain.symbol,
      sun: BigInt.zero,
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _tronAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _tronAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('Tron'), findsOneWidget);
    expect(find.text('Tron 手续费'), findsOneWidget);
    expect(find.text('0 TRX'), findsOneWidget);
    expect(find.text('0.1 TRX'), findsOneWidget);
    expect(find.text(_tronAccount.tronAddress), findsOneWidget);
    expect(find.text(recipient), findsOneWidget);
    expect(find.text('最大 Gas 费率'), findsNothing);
    expect(find.text('优先费率'), findsNothing);
    expect(find.text('Gas Price'), findsNothing);
  });

  testWidgets('Tron TRC20 confirmation shows contract transfer warning', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'tron-mainnet',
    );
    const recipient = 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi';
    const contractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
    const request = TransactionRequest(
      chainId: 'tron-mainnet',
      chainType: ChainType.tron,
      assetSymbol: 'USDT',
      toAddress: recipient,
      amount: '12.3456',
      amountInBaseUnits: '12345600',
      tokenDecimals: 6,
      tokenContractAddress: contractAddress,
      transactionType: TransactionType.trc20Transfer,
    );
    final feeEstimate = FeeEstimate.tron(
      feeAssetSymbol: chain.symbol,
      sun: BigInt.from(633000),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _tronAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _tronAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('USDT'), findsOneWidget);
    expect(find.text(contractAddress), findsOneWidget);
    expect(find.textContaining('这是合约代币转账'), findsOneWidget);
  });

  testWidgets('TRC20 custom maximum burn is shown without changing estimate', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'tron-mainnet',
    );
    const request = TransactionRequest(
      chainId: 'tron-mainnet',
      chainType: ChainType.tron,
      assetSymbol: 'USDT',
      toAddress: 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi',
      amount: '12.3456',
      amountInBaseUnits: '12345600',
      tokenDecimals: 6,
      tokenContractAddress: 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7',
      transactionType: TransactionType.trc20Transfer,
    );
    final feeEstimate = FeeEstimate.tron(
      feeAssetSymbol: chain.symbol,
      sun: BigInt.from(633000),
      feeLimitSun: BigInt.from(18000000),
    );
    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _tronAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _tronAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feeOption:custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customTronFeeLimit')), '0.5');
    await tester.tap(find.byKey(const Key('applyCustomFee')));
    await tester.pump();
    expect(find.text('最大可燃烧 TRX 不能低于预计手续费'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customTronFeeLimit')), '30');
    await tester.tap(find.byKey(const Key('applyCustomFee')));
    await tester.pumpAndSettle();

    expect(find.text('0.633 TRX'), findsOneWidget);
    expect(find.text('30 TRX'), findsOneWidget);
  });

  testWidgets('Sui confirmation shows simulated gas and no custom fee option', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere(
      (chain) => chain.id == 'sui-mainnet',
    );
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'SUI',
      toAddress:
          '0x0000000000000000000000000000000000000000000000000000000000000002',
      amount: '0.1',
      amountInBaseUnits: '100000000',
      tokenDecimals: 9,
      transactionType: TransactionType.suiTransfer,
    );
    final feeEstimate = FeeEstimate.sui(
      feeAssetSymbol: 'SUI',
      estimatedFeeMist: BigInt.from(900),
      gasBudgetMist: BigInt.from(1200),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _suiAccount,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            account: _suiAccount,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('Sui Gas 费'), findsOneWidget);
    expect(find.text('0.0000009 SUI'), findsOneWidget);
    expect(find.text('0.0000012 SUI'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feeOption:standard')), findsOneWidget);
    expect(find.byKey(const Key('feeOption:custom')), findsNothing);
  });

  testWidgets('confirmation shows memo tag when present', (tester) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = TransactionRequest(
      chainId: chain.chainId,
      chainType: chain.chainType,
      assetSymbol: chain.symbol,
      toAddress: '0x2222222222222222222222222222222222222222',
      amount: '0.1',
      amountInBaseUnits: '100000000000000000',
      tokenDecimals: 18,
      transactionType: TransactionType.nativeTransfer,
      memo: 'Invoice 123',
    );
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    expect(find.text('备注 / Tag'), findsOneWidget);
    expect(find.text('Invoice 123'), findsOneWidget);
  });

  testWidgets('locked confirm asks for identity without remember option', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final request = _transferRequest(chain);
    final feeEstimate = FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    );

    await tester.pumpWidget(
      _app(
        TransactionConfirmPage(
          chain: chain,
          rpcNode: _rpcNode(chain),
          account: _account,
          request: request,
          feeEstimate: feeEstimate,
          confirmation: _confirmation(
            chain: chain,
            request: request,
            feeEstimate: feeEstimate,
          ),
        ),
      ),
    );

    await tester.tap(find.text('提交'));
    await tester.pumpAndSettle();

    expect(find.text('验证签名身份'), findsOneWidget);
    expect(find.byKey(const Key('signingPasswordInput')), findsOneWidget);
    expect(find.text('15 分钟内记住密码'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}

Widget _app(Widget home) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(
        _SigningWalletRepository(),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
}

final class _SigningWalletRepository implements WalletRepository {
  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(
      account: _account,
      walletDek: List<int>.filled(32, 7),
    );
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
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

TransactionConfirmation _confirmation({
  required ChainConfig chain,
  WalletAccount? account,
  required TransactionRequest request,
  required FeeEstimate feeEstimate,
}) {
  return const TransactionConfirmController().buildConfirmation(
    chain: chain,
    account: account ?? _account,
    request: request,
    feeEstimate: feeEstimate,
  );
}

TransactionRequest _transferRequest(
  ChainConfig chain, {
  String toAddress = '0x2222222222222222222222222222222222222222',
}) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    toAddress: toAddress,
    amount: '0.1',
    amountInBaseUnits: '100000000000000000',
    tokenDecimals: 18,
    transactionType: TransactionType.nativeTransfer,
  );
}

RpcNode _rpcNode(ChainConfig chain) {
  return RpcNode(
    id: '${chain.id}-node',
    chainId: chain.chainId,
    name: 'RPC',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  );
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _bitcoinAccount = WalletAccount(
  id: 'wallet-btc',
  name: 'Bitcoin Wallet',
  evmAddress: '',
  solanaAddress: '',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _solanaAccount = WalletAccount(
  id: 'wallet-solana',
  name: 'Solana Wallet',
  evmAddress: '',
  solanaAddress: 'So11111111111111111111111111111111111111112',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _suiAccount = WalletAccount(
  id: 'wallet-sui',
  name: 'Sui Wallet',
  evmAddress: '',
  solanaAddress: '',
  suiAddress:
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _tronAccount = WalletAccount(
  id: 'wallet-tron',
  name: 'Tron Wallet',
  evmAddress: '',
  solanaAddress: '',
  tronAddress: 'TJ4uT7n9LQvz1J9jQK5hJkCcnHJfLgkSnj',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);
