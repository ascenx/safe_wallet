import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/export_secret_confirm_page.dart';
import 'package:safe_wallet/features/wallet/presentation/wallet_detail_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('wallet detail QR payloads use wallet URI formats', (
    tester,
  ) async {
    final wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
      source: WalletAccountSource.mnemonic,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WalletDetailPage(wallet: wallet),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final qrLabels = tester
        .widgetList<QrImageView>(find.byType(QrImageView))
        .map((qr) => qr.semanticsLabel)
        .toList();
    final evmQr = qrLabels.singleWhere(
      (label) => label.startsWith('ethereum:${wallet.evmAddress}?'),
    );
    final evmQrParameters = Uri.parse(evmQr).queryParameters;

    expect(evmQrParameters['chainName'], 'EVM');
    expect(evmQrParameters['label'], 'Main Wallet');
    expect(qrLabels, contains(wallet.solanaAddress));

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    final visibleQrLabels = tester
        .widgetList<QrImageView>(find.byType(QrImageView))
        .map((qr) => qr.semanticsLabel)
        .toList();
    expect(visibleQrLabels, contains(wallet.btcAddress));
  });

  testWidgets('Bitcoin private key wallet detail exports only the BTC key', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Bitcoin Wallet',
      evmAddress: '',
      solanaAddress: '',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
      source: WalletAccountSource.privateKey,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WalletDetailPage(wallet: wallet),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView, skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const Key('exportMnemonicButton'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('exportEvmPrivateKeyButton'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('exportBtcPrivateKeyButton'), skipOffstage: false),
      findsOneWidget,
    );

    final exportBtcButton = find.byKey(const Key('exportBtcPrivateKeyButton'));
    await tester.tap(exportBtcButton.first);
    await tester.pumpAndSettle();

    expect(find.byType(ExportSecretConfirmPage), findsNothing);
    expect(
      find.byKey(
        const Key('exportSecretPasswordSheet-btcPrivateKey'),
      ),
      findsOneWidget,
    );
  });
}
