import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/presentation/dapp_sheet_container.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('dApp sheets use 12px vertical drag handle spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: DappSheetContainer(child: Text('Sheet body')),
        ),
      ),
    );

    expect(find.byKey(const Key('appDragHandle')), findsOneWidget);
    final handlePadding = tester.widget<Padding>(
      find.byKey(const Key('appDragHandle')),
    );
    expect(
      handlePadding.padding,
      const EdgeInsets.symmetric(vertical: 12),
    );
  });
}
