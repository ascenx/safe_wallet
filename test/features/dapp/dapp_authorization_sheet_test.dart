import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/presentation/dapp_authorization_sheet.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  final confirmation = DappRequestConfirmation(
    kind: DappConfirmationKind.authorization,
    domain: 'app.uniswap.org',
    chain: defaultChains.first,
    address: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
  );

  testWidgets('dApp approval is session-only by default', (tester) async {
    DappAuthorizationDecision? decision;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                decision = await showDappAuthorizationSheet(
                  context,
                  confirmation,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.dapp.approve));
    await tester.pumpAndSettle();

    expect(decision, DappAuthorizationDecision.approvedForSession);
  });
}
