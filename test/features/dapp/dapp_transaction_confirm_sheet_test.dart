import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/presentation/dapp_transaction_confirm_sheet.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('transaction confirmation displays raw transaction data', (
    tester,
  ) async {
    const rawData = '0x01020304';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: DappTransactionConfirmSheet(
              confirmation: DappRequestConfirmation(
                kind: DappConfirmationKind.transaction,
                domain: 'example.com',
                chain: ChainConfig(
                  id: 'solana-mainnet',
                  chainType: ChainType.solana,
                  name: 'Solana',
                  chainId: 'mainnet-beta',
                  symbol: 'SOL',
                  rpcUrls: ['https://rpc.example.com'],
                  blockExplorerUrl: 'https://solscan.io',
                  isTestnet: false,
                ),
                address: 'sender',
                transaction: DappTransactionPreview(
                  from: 'sender',
                  data: rawData,
                  highRisk: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('原始交易数据'), findsOneWidget);
    expect(find.text(rawData), findsOneWidget);
  });

  testWidgets('transaction confirmation displays every batch item in full', (
    tester,
  ) async {
    const longSummary =
        'Instruction one; instruction two; instruction three; instruction four; '
        'instruction five; instruction six; instruction seven; instruction eight';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: DappTransactionConfirmSheet(
              confirmation: DappRequestConfirmation(
                kind: DappConfirmationKind.transaction,
                domain: 'example.com',
                chain: ChainConfig(
                  id: 'solana-mainnet',
                  chainType: ChainType.solana,
                  name: 'Solana',
                  chainId: 'mainnet-beta',
                  symbol: 'SOL',
                  rpcUrls: ['https://rpc.example.com'],
                  blockExplorerUrl: 'https://solscan.io',
                  isTestnet: false,
                ),
                address: 'sender',
                transactions: [
                  DappTransactionPreview(
                    from: 'sender',
                    data: '0x0102',
                    decodedInfo: longSummary,
                    highRisk: true,
                  ),
                  DappTransactionPreview(
                    from: 'sender',
                    data: '0x0304',
                    highRisk: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0x0102'), findsOneWidget);
    expect(find.text('0x0304'), findsOneWidget);
    final summary = tester.widget<Text>(find.text(longSummary));
    expect(summary.maxLines, isNull);
    expect(summary.overflow, isNot(TextOverflow.ellipsis));
  });
}
