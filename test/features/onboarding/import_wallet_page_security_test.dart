import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app_lifecycle_observer.dart';
import 'package:safe_wallet/features/onboarding/presentation/import_wallet_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  testWidgets('pasting does not show the privacy shield', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          return <String, Object?>{
            'text':
                'abandon abandon abandon abandon abandon abandon '
                'abandon abandon abandon abandon abandon about',
          };
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            navigatorKey: container.read(appNavigatorKeyProvider),
            theme: buildAppTheme(),
            home: const AppLifecycleObserver(child: ImportWalletPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    await tester.tap(find.descendant(of: sheet, matching: find.text('助记词钱包')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '粘贴'));
    await tester.pump();

    expect(find.byKey(const Key('appPrivacyShield')), findsNothing);
    final secretField = tester.widget<TextField>(
      find.byKey(const Key('mnemonicInput')),
    );
    expect(secretField.controller?.text, startsWith('abandon abandon'));
    expect(secretField.autocorrect, isFalse);
    expect(secretField.enableSuggestions, isFalse);
    expect(secretField.enableIMEPersonalizedLearning, isFalse);
    expect(secretField.smartDashesType, SmartDashesType.disabled);
    expect(secretField.smartQuotesType, SmartQuotesType.disabled);
  });

  testWidgets('import wallet page protects the screen while mounted', (
    tester,
  ) async {
    final protectionCalls = <bool>[];
    const channel = MethodChannel('safe_wallet/security');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'setSensitiveScreenProtection') {
        final arguments = call.arguments as Map<Object?, Object?>;
        protectionCalls.add(arguments['enabled'] as bool);
      }
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ImportWalletPage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(protectionCalls, [true]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(protectionCalls, [true, false]);
  });

  testWidgets('import wallet opens wallet type picker before mnemonic input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ImportWalletPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('助记词钱包')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('私钥钱包')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mnemonicInput')), findsNothing);

    await tester.tap(find.descendant(of: sheet, matching: find.text('助记词钱包')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('mnemonicInput')), findsOneWidget);
    expect(find.text('私钥钱包'), findsNothing);
    expect(find.text('请输入助记词，12或24个单词，用空格分隔'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '粘贴'), findsOneWidget);
  });

  testWidgets('private key import asks for chain before private key input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const ImportWalletPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);

    await tester.tap(find.descendant(of: sheet, matching: find.text('私钥钱包')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('EVM'), findsOneWidget);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Solana'), findsOneWidget);
    expect(find.text('Sui'), findsOneWidget);
    expect(find.byKey(const Key('privateKeyInput')), findsNothing);

    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privateKeyInput')), findsOneWidget);
    expect(
      find.text('支持 EVM hex、Bitcoin WIF/hex、Solana 私钥或 Sui suiprivkey'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '粘贴'), findsOneWidget);
  });
}
