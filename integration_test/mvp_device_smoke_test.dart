import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/app/app_bootstrap.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MVP device smoke', () {
    testWidgets('create wallet, navigate, switch language, lock and unlock', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

      final storageDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_mvp_device_smoke_',
      );
      addTearDown(() async {
        await Hive.close();
        if (storageDirectory.existsSync()) {
          await storageDirectory.delete(recursive: true);
        }
      });
      final registry = await StorageInitializer(
        path: storageDirectory.path,
      ).initialize();
      final localeStore = HiveLocalePreferenceStore(registry: registry);
      await localeStore.saveLocaleMode(AppLocaleMode.zh);
      await Hive.close();

      final app = await tester.runAsync(() {
        return bootstrapApp(
          storagePath: storageDirectory.path,
          child: const SafeWalletApp(),
        );
      });
      if (app == null) {
        fail('bootstrapApp did not return a widget');
      }

      await tester.pumpWidget(app);
      await _pumpUntilFound(tester, find.text('创建钱包'));

      await _tapElevatedButton(tester, '创建钱包');
      await _pumpUntilFound(tester, find.text('创建新钱包'));

      await _tapElevatedButton(tester, '继续');
      await _pumpUntilFound(tester, find.text('助记词丢失后无法找回钱包'));

      await _tapElevatedButton(tester, '我已了解风险');
      await _pumpUntilFound(tester, find.byKey(const Key('passwordInput')));

      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'StrongPass123',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'StrongPass123',
      );
      await _tapElevatedButton(tester, '完成');
      await _pumpUntilFound(tester, find.text('总资产估值'), maxPumps: 240);
      await _pumpUntilFound(tester, find.text('ETH'), maxPumps: 240);
      await _pumpUntilFound(tester, find.text('USDC'), maxPumps: 240);
      await tester.pumpAndSettle();

      expect(find.text('资产加载失败'), findsNothing);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('浏览器'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);

      await _tapVisible(tester, find.byTooltip('刷新资产'));
      await _pumpUntilFound(tester, find.text('ETH'), maxPumps: 240);
      await _pumpUntilFound(tester, find.text('USDC'), maxPumps: 240);
      expect(find.text('资产加载失败'), findsNothing);

      await tester.ensureVisible(find.text('管理代币'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理代币'));
      await _pumpUntilFound(tester, find.text('代币管理'));
      await tester.tap(find.text('添加代币'));
      await _pumpUntilFound(tester, find.widgetWithText(TextField, '合约地址'));
      await tester.enterText(
        find.widgetWithText(TextField, '合约地址'),
        '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '代币符号'),
        'UNI',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '代币名称'),
        'Uniswap',
      );
      await tester.tap(find.text('确认').last);
      await _pumpUntilGone(
        tester,
        find.widgetWithText(TextField, '合约地址'),
        maxPumps: 240,
      );
      await _pumpUntilFound(tester, find.text('UNI'), maxPumps: 240);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.byType(NavigationBar));
      await _pumpUntilFound(tester, find.text('UNI'), maxPumps: 240);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.public_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('DEX'));
      expect(find.text('Uniswap'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('钱包管理'));
      expect(find.text('网络管理'), findsOneWidget);
      expect(find.text('安全设置'), findsOneWidget);

      await tester.tap(find.text('网络管理'));
      await _pumpUntilFound(tester, find.text('Solana Mainnet'));
      await tester.ensureVisible(find.text('Solana Mainnet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solana Mainnet'));
      await _pumpUntilFound(tester, find.text('RPC 节点'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('新增 EVM 网络'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('钱包管理'));

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.home_outlined),
        ),
      );
      await _pumpUntilFound(tester, find.text('SOL'), maxPumps: 240);
      expect(find.text('资产加载失败'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await _pumpUntilFound(tester, find.text('钱包管理'));

      await tester.tap(find.text('多语言设置'));
      await _pumpUntilFound(tester, find.text('English'));
      await tester.tap(find.text('English'));
      await _pumpUntilFound(tester, find.text('Language'));
      _expectNoVisibleHanText(tester);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Wallet Management'));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      _expectNoVisibleHanText(tester);

      await _tapVisible(tester, find.text('Wallet Management'));
      await _pumpUntilFound(tester, find.text('Create Wallet'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('View'));
      await _pumpUntilFound(tester, find.text('EVM Address'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Export Mnemonic'));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('exportSecretPasswordInput')),
      );
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('EVM Address'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Create Wallet'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Network Management'));

      await _tapVisible(tester, find.text('Network Management'));
      await _pumpUntilFound(tester, find.text('Add EVM Network'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Add EVM Network'));
      await _pumpUntilFound(
        tester,
        find.widgetWithText(TextField, 'Network Name'),
      );
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Add EVM Network'));
      await _tapVisible(tester, find.text('Solana Mainnet'));
      await _pumpUntilFound(tester, find.text('RPC Nodes'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Add Node'));
      await _pumpUntilFound(
        tester,
        find.widgetWithText(TextField, 'Node Name'),
      );
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('RPC Nodes'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Add EVM Network'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Address Book'));

      await _tapVisible(tester, find.text('Address Book'));
      await _pumpUntilFound(tester, find.text('No contacts'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Add Contact'));
      await _pumpUntilFound(tester, find.text('Chain Type'));
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('No contacts'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Security'));

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.public_outlined),
        ),
      );
      await _pumpUntilFound(tester, find.text('Favorites'));
      _expectNoVisibleHanText(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.home_outlined),
        ),
      );
      await _pumpUntilFound(tester, find.text('Total Value'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Receive').last);
      await _pumpUntilFound(tester, find.byKey(const Key('addressQrCard')));
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Total Value'));

      await _tapVisible(tester, find.text('Send').last);
      await _pumpUntilFound(tester, find.text('Recipient Address'));
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Total Value'));

      await _tapVisible(tester, find.text('Manage Tokens'));
      await _pumpUntilFound(tester, find.text('Token Management'));
      _expectNoVisibleHanText(tester);
      await _tapVisible(tester, find.text('Add Token'));
      await _pumpUntilFound(
        tester,
        find.widgetWithText(TextField, 'Contract Address'),
      );
      _expectNoVisibleHanText(tester);
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Token Management'));
      _popTopRoute(tester);
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Total Value'));

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await _pumpUntilFound(tester, find.text('Security'));

      await _tapVisible(tester, find.text('Security'));
      await _pumpUntilFound(tester, find.text('Lock Now'));
      _expectNoVisibleHanText(tester);
      await tester.tap(find.text('Lock Now'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await _pumpUntilFound(tester, find.text('Unlock Wallet'));

      await tester.enterText(
        find.byKey(const Key('unlockPasswordInput')),
        'StrongPass123',
      );
      await _tapElevatedButton(tester, 'Unlock');
      await _pumpUntilFound(tester, find.text('Home'), maxPumps: 160);
    });
  });
}

void _popTopRoute(WidgetTester tester) {
  final context = tester.element(find.byType(Scaffold).last);
  Navigator.of(context).pop();
}

void _expectNoVisibleHanText(WidgetTester tester) {
  final hanPattern = RegExp(r'[\u4e00-\u9fff]');
  final visibleHanTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .where(hanPattern.hasMatch)
      .toList(growable: false);
  expect(visibleHanTexts, isEmpty);
}

Future<void> _tapElevatedButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label).last;
  final box = tester.renderObject<RenderBox>(button);
  final center = box.localToGlobal(box.size.center(Offset.zero));
  final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  await tester.tapAt(
    Offset(
      center.dx.clamp(1, viewSize.width - 1).toDouble(),
      center.dy.clamp(1, viewSize.height - 1).toDouble(),
    ),
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _pumpUntilFound(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  fail('Timed out waiting for $finder. Visible texts: $visibleTexts');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  fail(
      'Timed out waiting for $finder to disappear. Visible texts: $visibleTexts');
}
