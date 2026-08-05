import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safe_wallet/app/shell/main_shell_tab.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/receive_qr_image_saver.dart';
import 'package:safe_wallet/features/wallet/application/receive_qr_image_saver_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/export_secret_confirm_page.dart';
import 'package:safe_wallet/features/wallet/presentation/wallet_management_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_radius.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/widgets/app_buttons.dart';

void main() {
  group('Wallet management', () {
    final account = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      source: WalletAccountSource.mnemonic,
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    final privateKeyAccount = WalletAccount(
      id: 'wallet-private-key',
      name: 'Private Key Wallet',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '',
      source: WalletAccountSource.privateKey,
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    final bitcoinPrivateKeyAccount = WalletAccount(
      id: 'wallet-bitcoin-private-key',
      name: 'Bitcoin Private Key Wallet',
      evmAddress: '',
      solanaAddress: '',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      source: WalletAccountSource.privateKey,
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    testWidgets('shows the page title only in the app bar', (tester) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          chainRepository: _FakeChainRepository(),
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('钱包管理'), findsOneWidget);
    });

    testWidgets('import wallet action uses a downward arrow icon', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          chainRepository: _FakeChainRepository(),
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.arrowDown), findsOneWidget);
      expect(find.byIcon(Icons.file_upload_outlined), findsNothing);
    });

    testWidgets('create wallet action is the primary themed button', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          chainRepository: _FakeChainRepository(),
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '创建钱包'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '导入钱包'), findsOneWidget);
    });

    testWidgets(
      'create wallet action matches import button height and radius',
      (tester) async {
        final repository = _FakeWalletRepository(accounts: [account]);

        await tester.pumpWidget(
          _walletApp(
            repository: repository,
            home: const WalletManagementPage(),
          ),
        );
        await tester.pumpAndSettle();

        final createButtonFinder = find.widgetWithText(FilledButton, '创建钱包');
        final importButtonFinder = find.widgetWithText(OutlinedButton, '导入钱包');
        final createButton = tester.widget<FilledButton>(createButtonFinder);

        expect(
          tester.getSize(createButtonFinder).height,
          tester.getSize(importButtonFinder).height,
        );
        expect(tester.getSize(createButtonFinder).height, 52);
        expect(
          createButton.style?.shape?.resolve({}),
          const RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
        );
      },
    );

    testWidgets('create and import wallet actions are pinned to the bottom', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      final createButtonBottom = tester
          .getBottomLeft(find.widgetWithText(FilledButton, '创建钱包'))
          .dy;
      final importButtonBottom = tester
          .getBottomLeft(find.widgetWithText(OutlinedButton, '导入钱包'))
          .dy;

      expect(createButtonBottom, greaterThan(780));
      expect(importButtonBottom, greaterThan(780));
    });

    testWidgets('export secret page protects the screen while mounted', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
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
        _walletApp(
          repository: repository,
          home: ExportSecretConfirmPage(
            secret: _FakeWalletRepository.mnemonic,
            secretType: WalletSecretType.mnemonic,
          ),
        ),
      );
      await tester.pump();

      expect(protectionCalls, [true]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(protectionCalls, [true, false]);
    });

    testWidgets('export secret requires password', (tester) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('导出'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('导出助记词'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ExportSecretConfirmPage), findsNothing);
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('exportSecretPasswordInput')),
      );
      expect(passwordField.autofocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pump();

      expect(repository.exportCallCount, 0);
      expect(find.text('请输入钱包密码'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('exportSecretPasswordInput')),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(repository.exportCallCount, 1);
      expect(repository.lastExportPassword, 'password');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ExportSecretConfirmPage), findsOneWidget);
      expect(find.byKey(const Key('exportSecretPasswordInput')), findsNothing);
      expect(find.text(_FakeWalletRepository.mnemonic), findsOneWidget);
    });

    testWidgets('export secret shows password lockout errors', (tester) async {
      final repository = _FakeWalletRepository(
        accounts: [account],
        exportError: const WalletError.passwordAttemptLocked(),
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('导出'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('导出助记词'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('exportSecretPasswordInput')),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(repository.exportCallCount, 1);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(ExportSecretConfirmPage), findsNothing);
      expect(find.text('密码错误次数过多，请稍后再试'), findsOneWidget);
      expect(find.text(_FakeWalletRepository.mnemonic), findsNothing);
    });

    testWidgets('delete wallet requires password and confirmation', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await _openWalletActions(tester, account.id);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteWalletButton')));
      await tester.pump();

      expect(repository.deletedWalletId, isNull);
      expect(find.text('请输入钱包密码'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('deleteWalletPasswordInput')),
        'password',
      );
      await tester.tap(find.byKey(const Key('confirmDeleteWalletButton')));
      await tester.pump();

      expect(repository.deletedWalletId, isNull);

      await tester.tap(
        find.byKey(const Key('deleteWalletAcknowledgeCheckbox')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmDeleteWalletButton')));
      await tester.pumpAndSettle();

      expect(repository.deletedWalletId, account.id);
      expect(repository.lastDeletePassword, 'password');
    });

    testWidgets('delete wallet does not recover a saved biometric password', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: _FakeSecurePasswordStorage()..password = 'saved-password',
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: biometricStore,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      await _openWalletActions(tester, account.id);
      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const Key('deleteWalletPasswordInput')),
        'manual-password',
      );
      await tester.tap(
        find.byKey(const Key('deleteWalletAcknowledgeCheckbox')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmDeleteWalletButton')));
      await tester.pumpAndSettle();

      expect(repository.deletedWalletId, account.id);
      expect(repository.lastDeletePassword, 'manual-password');
    });

    testWidgets('delete wallet shows password lockout errors', (tester) async {
      final repository = _FakeWalletRepository(
        accounts: [account],
        deleteError: const WalletError.passwordAttemptLocked(),
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await _openWalletActions(tester, account.id);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('deleteWalletPasswordInput')),
        'password',
      );
      await tester.tap(
        find.byKey(const Key('deleteWalletAcknowledgeCheckbox')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirmDeleteWalletButton')));
      await tester.pumpAndSettle();

      expect(repository.deletedWalletId, isNull);
      expect(find.text('密码错误次数过多，请稍后再试'), findsOneWidget);
    });

    testWidgets('wallet tiles show source labels and only primary actions', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account, privateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('助记词'), findsOneWidget);
      expect(find.text('私钥'), findsOneWidget);
      expect(find.text('查看'), findsNWidgets(2));
      expect(find.text('导出'), findsNWidgets(2));
      expect(find.byKey(Key('walletActions-${account.id}')), findsOneWidget);
      expect(
        find.byKey(Key('walletActions-${privateKeyAccount.id}')),
        findsOneWidget,
      );
      expect(find.text('复制 EVM 地址'), findsNothing);
      expect(find.text('复制 Solana 地址'), findsNothing);
      expect(find.text('接收二维码'), findsNothing);
      expect(find.text('修改密码'), findsNothing);
      expect(find.text('切换钱包'), findsNothing);
      expect(find.text('导出助记词'), findsNothing);
      expect(find.text('导出私钥'), findsNothing);
    });

    testWidgets('wallet tiles show Bitcoin addresses when present', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account, bitcoinPrivateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          account.btcAddress,
          within: _walletCard('Main Wallet'),
        ),
        account.btcAddress,
      );
      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          bitcoinPrivateKeyAccount.btcAddress,
          within: _walletCard('Bitcoin Private Key Wallet'),
        ),
        bitcoinPrivateKeyAccount.btcAddress,
      );
    });

    testWidgets('source label is placed next to the wallet name', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      final labelLeft = tester.getTopLeft(find.text('助记词')).dx;

      expect(labelLeft, lessThan(320));
    });

    testWidgets('selected wallet tile uses the primary border color', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account, privateKeyAccount],
      );
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const WalletManagementPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_walletTileBorderColor(tester, account.id), AppColors.primary);
      expect(
        _walletTileBorderColor(tester, privateKeyAccount.id),
        AppColors.border,
      );
    });

    testWidgets(
      'mnemonic wallet export chooses private key network after type',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final repository = _FakeWalletRepository(accounts: [account]);

        await tester.pumpWidget(
          _walletApp(
            repository: repository,
            chainRepository: _FakeChainRepository(),
            home: const WalletManagementPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: _walletCard('Main Wallet'),
            matching: find.text('导出'),
          ),
        );
        await tester.pumpAndSettle();

        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text('导出助记词')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('导出私钥')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.text('导出 BTC 私钥')),
          findsNothing,
        );

        await tester.tap(
          find.descendant(of: sheet, matching: find.text('导出私钥')),
        );
        await tester.pumpAndSettle();

        final networkSheet = find.byType(BottomSheet);
        expect(networkSheet, findsOneWidget);
        expect(
          find.descendant(of: networkSheet, matching: find.text('Ethereum')),
          findsOneWidget,
        );
        final networkList = find.descendant(
          of: networkSheet,
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Bitcoin'),
          200,
          scrollable: networkList,
        );
        expect(
          find.descendant(of: networkSheet, matching: find.text('Bitcoin')),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Solana Mainnet'),
          200,
          scrollable: networkList,
        );
        expect(
          find.descendant(
            of: networkSheet,
            matching: find.text('Solana Mainnet'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: networkSheet,
            matching: find.text('Solana Mainnet'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExportSecretConfirmPage), findsNothing);
        expect(
          find.byKey(const Key('exportSecretPasswordSheet-solanaPrivateKey')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Bitcoin private key wallet exports the Bitcoin private key', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [bitcoinPrivateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Bitcoin Private Key Wallet'),
          matching: find.text('导出'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExportSecretConfirmPage), findsNothing);
      expect(
        find.byKey(const Key('exportSecretPasswordSheet-btcPrivateKey')),
        findsOneWidget,
      );
    });

    testWidgets('Solana private key wallet exports the Solana private key', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [
          WalletAccount(
            id: 'wallet-solana-private-key',
            name: 'Solana Private Key Wallet',
            evmAddress: '',
            solanaAddress: 'So11111111111111111111111111111111111111112',
            source: WalletAccountSource.privateKey,
            createdAt: DateTime.utc(2026, 6, 6),
            updatedAt: DateTime.utc(2026, 6, 6),
          ),
        ],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Solana Private Key Wallet'),
          matching: find.text('导出'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExportSecretConfirmPage), findsNothing);
      expect(
        find.byKey(const Key('exportSecretPasswordSheet-solanaPrivateKey')),
        findsOneWidget,
      );
    });

    testWidgets('tapping wallet tile selects it and returns home', (
      tester,
    ) async {
      final secondAccount = WalletAccount(
        id: 'wallet-2',
        name: 'Second Wallet',
        evmAddress: '0x1111111111111111111111111111111111111111',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      );
      final repository = _FakeWalletRepository(
        accounts: [account, secondAccount],
      );
      final container = ProviderContainer(
        overrides: [walletRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      container
          .read(mainShellTabProvider.notifier)
          .select(MainShellTab.settings);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const _WalletManagementHost(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Wallet Management'));
      await tester.pumpAndSettle();

      expect(_selectedMarkerInsideWallet('Main Wallet'), findsOneWidget);
      expect(_selectedMarkerInsideWallet('Second Wallet'), findsNothing);

      await tester.tap(find.text('Second Wallet'));
      await tester.pumpAndSettle();

      expect(container.read(selectedWalletIdProvider), 'wallet-2');
      expect(container.read(mainShellTabProvider), MainShellTab.home);
      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.text('Second Wallet'), findsNothing);
    });

    testWidgets('create wallet dialog saves and refreshes the wallet list', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建钱包'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final createDialogButton = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, '创建钱包'),
      );

      expect(find.byKey(const Key('createWalletPasswordInput')), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '钱包名称'),
        'Second Wallet',
      );
      await tester.enterText(
        find.byKey(const Key('createWalletPasswordInput')),
        'StrongPass-123',
      );
      await tester.tap(createDialogButton);
      await tester.pumpAndSettle();

      expect(repository.createWalletCallCount, 1);
      expect(repository.lastCreateWalletName, 'Second Wallet');
      expect(repository.lastCreateWalletPassword, 'StrongPass-123');
      expect(find.text('Second Wallet'), findsOneWidget);
    });

    testWidgets('create wallet name increments from existing wallets', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account, privateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('创建钱包'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final nameField = tester.widget<TextField>(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('createWalletNameInput')),
        ),
      );
      expect(nameField.controller?.text, 'Wallet 3');
    });

    testWidgets('rename wallet dialog saves and refreshes the wallet list', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await _openWalletActions(tester, account.id);
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '钱包名称'),
        'Renamed Wallet',
      );
      await tester.tap(find.widgetWithText(FilledButton, '重命名'));
      await tester.pumpAndSettle();

      expect(repository.renameWalletCallCount, 1);
      expect(repository.lastRenamedWalletId, account.id);
      expect(repository.lastRenamedWalletName, 'Renamed Wallet');
      expect(find.text('Renamed Wallet'), findsOneWidget);
      expect(find.text('Main Wallet'), findsNothing);
    });

    testWidgets('wallet action sheet contains rename and delete', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await _openWalletActions(tester, account.id);

      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('view dialog selects concrete networks from bottom sheet', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final chainRepository = _FakeChainRepository();

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          chainRepository: chainRepository,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('receiveQrNetworkSelector')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('receiveQrChainSegmentedTabs')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Ethereum')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byIcon(AppIcons.chevronDown),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('EVM')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(QrImageView)),
        findsOneWidget,
      );
      final ethereumQr = tester.widget<QrImageView>(
        find.descendant(
          of: find.byKey(const Key('receiveQrPageContent-Ethereum')),
          matching: find.byType(QrImageView),
        ),
      );
      expect(
        ethereumQr.semanticsLabel,
        startsWith('ethereum:${account.evmAddress}@1?'),
      );
      final qrParameters = Uri.parse(ethereumQr.semanticsLabel).queryParameters;
      expect(qrParameters['chainName'], 'Ethereum');
      expect(qrParameters['label'], 'Main Wallet');
      expect(
        find.descendant(of: dialog, matching: find.text('0x98...eda94')),
        findsNothing,
      );
      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          account.evmAddress,
          within: dialog,
        ),
        account.evmAddress,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Main Wallet - Ethereum'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('receiveQrNetworkSelector')));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('BNB Smart Chain'), findsOneWidget);

      await tester.tap(find.text('BNB Smart Chain'));
      await tester.pumpAndSettle();

      expect(find.text('Main Wallet - BNB Smart Chain'), findsOneWidget);
      final bnbQr = tester.widget<QrImageView>(
        find.descendant(
          of: find.byKey(const Key('receiveQrPageContent-BNB Smart Chain')),
          matching: find.byType(QrImageView),
        ),
      );
      expect(
        bnbQr.semanticsLabel,
        startsWith('ethereum:${account.evmAddress}@56?'),
      );
      expect(
        Uri.parse(bnbQr.semanticsLabel).queryParameters['chainName'],
        'BNB Smart Chain',
      );
      expect(chainRepository.selectedChainId, 'ethereum');
    });

    testWidgets('wallet item view includes the Sui receive address', (
      tester,
    ) async {
      const suiAddress =
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final suiAccount = WalletAccount(
        id: 'wallet-sui',
        name: 'Sui Wallet',
        evmAddress: '',
        solanaAddress: '',
        suiAddress: suiAddress,
        source: WalletAccountSource.privateKey,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      );
      final repository = _FakeWalletRepository(accounts: [suiAccount]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          suiAddress,
          within: _walletCard('Sui Wallet'),
        ),
        suiAddress,
      );

      await tester.tap(
        find.descendant(
          of: _walletCard('Sui Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('receiveQrPageContent-Sui Mainnet')),
        findsOneWidget,
      );
      final qr = tester.widget<QrImageView>(
        find.descendant(
          of: find.byKey(const Key('receiveQrPageContent-Sui Mainnet')),
          matching: find.byType(QrImageView),
        ),
      );
      expect(qr.semanticsLabel, suiAddress);
      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          suiAddress,
          within: find.byType(AlertDialog),
        ),
        suiAddress,
      );
    });

    testWidgets('Bitcoin private key wallet view shows only the Bitcoin QR', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [bitcoinPrivateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Bitcoin Private Key Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('receiveQrChainSegmentedTabs')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byKey(const Key('receiveQrPageContent-Ethereum')),
        ),
        findsNothing,
      );
      final bitcoinQr = tester.widget<QrImageView>(
        find.descendant(
          of: find.byKey(const Key('receiveQrPageContent-Bitcoin')),
          matching: find.byType(QrImageView),
        ),
      );
      expect(bitcoinQr.semanticsLabel, bitcoinPrivateKeyAccount.btcAddress);
      expect(
        find.byKey(const Key('copyReceiveQrButton-Bitcoin')),
        findsOneWidget,
      );
    });

    testWidgets('receive QR cards show save before copy actions', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      final evmCard = find.byKey(const Key('receiveQrCard'));
      final saveButton = find.byKey(const Key('saveReceiveQrButton-Ethereum'));
      final copyButton = find.byKey(const Key('copyReceiveQrButton-Ethereum'));
      final exportContent = find.byKey(
        const Key('receiveQrExportContent-Ethereum'),
      );
      final pageContent = find.byKey(
        const Key('receiveQrPageContent-Ethereum'),
      );

      expect(evmCard, findsOneWidget);
      expect(saveButton, findsOneWidget);
      expect(copyButton, findsOneWidget);
      expect(pageContent, findsOneWidget);
      expect(
        find.descendant(of: pageContent, matching: exportContent),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pageContent, matching: saveButton),
        findsNothing,
      );
      expect(
        find.descendant(of: pageContent, matching: copyButton),
        findsNothing,
      );
      expect(
        find.descendant(
          of: pageContent,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(saveButton).dy -
            tester.getBottomLeft(exportContent).dy,
        lessThanOrEqualTo(8),
      );
      expect(
        tester.getTopLeft(saveButton).dx,
        lessThan(tester.getTopLeft(copyButton).dx),
      );
      expect(tester.getTopLeft(saveButton).dx, tester.getTopLeft(evmCard).dx);
      expect(tester.getTopRight(copyButton).dx, tester.getTopRight(evmCard).dx);
      expect(
        tester.getBottomLeft(saveButton).dy,
        tester.getBottomLeft(evmCard).dy,
      );
      expect(
        tester.getBottomRight(copyButton).dy,
        tester.getBottomRight(evmCard).dy,
      );
      expect(
        tester.getSize(saveButton).width,
        tester.getSize(copyButton).width,
      );
      expect(tester.getSize(saveButton).height, 40);
      expect(tester.getSize(copyButton).height, 40);
      expect(
        find.descendant(of: copyButton, matching: find.text('复制')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: evmCard, matching: find.text('复制地址')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: exportContent,
          matching: find.text('Main Wallet - Ethereum'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: exportContent, matching: find.text('0x98...eda94')),
        findsNothing,
      );
      _expectHighlightedAddress(
        _addressTextSpanWithPlainText(
          tester,
          account.evmAddress,
          within: exportContent,
        ),
        account.evmAddress,
      );
      expect(
        find.descendant(of: exportContent, matching: find.byType(QrImageView)),
        findsOneWidget,
      );
      final qr = tester.widget<QrImageView>(
        find.descendant(of: exportContent, matching: find.byType(QrImageView)),
      );
      expect(
        qr.semanticsLabel,
        startsWith('ethereum:${account.evmAddress}@1?'),
      );
      final qrParameters = Uri.parse(qr.semanticsLabel).queryParameters;
      expect(qrParameters['chainName'], 'Ethereum');
      expect(qrParameters['label'], 'Main Wallet');
      expect(
        find.descendant(of: exportContent, matching: find.byType(AppButton)),
        findsNothing,
      );
    });

    testWidgets('saving Ethereum QR writes a PNG and shows success', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final saver = _FakeReceiveQrImageSaver();

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          receiveQrImageSaver: saver,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveReceiveQrButton-Ethereum')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(saver.saveCallCount, 1);
      expect(saver.savedBytes, isNotNull);
      expect(saver.savedBytes!.sublist(0, 8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      expect(
        saver.savedFileName,
        matches(RegExp(r'^safe-wallet-ethereum-receive-\d+\.png$')),
      );
      expect(find.text('二维码已保存到相册'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('generic save failure shows the retry message', (tester) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final saver = _FakeReceiveQrImageSaver(
        error: StateError('gallery write failed'),
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          receiveQrImageSaver: saver,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveReceiveQrButton-Ethereum')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('二维码保存失败，请重试'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('permission denial shows the photo access message', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final saver = _FakeReceiveQrImageSaver(
        error: const ReceiveQrImageSaveException(
          ReceiveQrImageSaveFailure.permissionDenied,
        ),
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          receiveQrImageSaver: saver,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveReceiveQrButton-Ethereum')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();

      expect(find.text('需要相册权限才能保存二维码'), findsOneWidget);
      expect(find.text('二维码保存失败，请重试'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('repeated save taps create only one image while saving', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final completer = Completer<void>();
      final saver = _FakeReceiveQrImageSaver(completer: completer);

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          receiveQrImageSaver: saver,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _walletCard('Main Wallet'),
          matching: find.text('查看'),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('saveReceiveQrButton-Ethereum'));
      await tester.tap(saveButton);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pump();

      expect(saver.saveCallCount, 1);

      completer.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('locked import unlocks first and then opens the type picker', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: false,
          authenticateResult: false,
        ),
        storage: _FakeSecurePasswordStorage(),
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: biometricStore,
          unlockSession: false,
          home: const WalletManagementPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unlockPasswordInput')), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.enterText(
        find.byKey(const Key('unlockPasswordInput')),
        'wallet-password',
      );
      await tester.tap(find.text('解锁'));
      await tester.pumpAndSettle();

      expect(repository.unlockCallCount, 1);
      expect(repository.lastUnlockWalletId, account.id);
      expect(repository.lastUnlockPassword, 'wallet-password');
      expect(find.byKey(const Key('unlockPasswordInput')), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('助记词钱包'), findsOneWidget);
      expect(find.text('私钥钱包'), findsOneWidget);
    });

    testWidgets('import mnemonic shows localized validation errors', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account],
        importMnemonicError: const WalletError.invalidMnemonic(),
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('walletImportPage')), findsNothing);
      final importTypeSheet = find.byType(BottomSheet);
      expect(importTypeSheet, findsOneWidget);
      expect(
        find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: importTypeSheet, matching: find.text('私钥钱包')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: importTypeSheet, matching: find.text('多链钱包')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: importTypeSheet,
          matching: find.text('EVM、Bitcoin、Tron、Solana 或 Sui 钱包'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('importWalletPasswordInput')), findsNothing);

      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('walletImportPage')), findsOneWidget);
      expect(find.byKey(const Key('mnemonicInput')), findsOneWidget);
      expect(find.byKey(const Key('mnemonicWordCount12')), findsNothing);
      expect(find.byKey(const Key('mnemonicWord-1')), findsNothing);
      expect(find.text('请输入助记词，12或24个单词，用空格分隔'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '粘贴'), findsOneWidget);
      expect(find.byKey(const Key('importWalletPasswordInput')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mnemonicInput')),
        'invalid words',
      );
      await tester.enterText(
        find.byKey(const Key('importWalletPasswordInput')),
        'StrongPass-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, '导入钱包'));
      await tester.pumpAndSettle();

      expect(repository.importMnemonicCallCount, 1);
      expect(repository.lastImportedMnemonic, 'invalid words');
      expect(find.text('助记词格式或校验和无效'), findsOneWidget);
      expect(find.text('操作失败，请稍后重试'), findsNothing);
    });

    testWidgets('import renders loading before starting key derivation', (
      tester,
    ) async {
      final importCompleter = Completer<WalletAccount>();
      final repository = _FakeWalletRepository(
        accounts: [account],
        importMnemonicCompleter: importCompleter,
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();
      final importTypeSheet = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('mnemonicInput')),
        _FakeWalletRepository.mnemonic,
      );
      await tester.enterText(
        find.byKey(const Key('importWalletPasswordInput')),
        'StrongPass-123',
      );

      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '导入钱包'),
      );
      importButton.onPressed!();

      expect(repository.importMnemonicCallCount, 0);

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(repository.importMnemonicCallCount, 1);

      importCompleter.complete(account);
      await tester.pumpAndSettle();
    });

    testWidgets('import wallet name increments from existing wallets', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account, privateKeyAccount],
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();
      final importTypeSheet = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('importWalletName')),
      );
      expect(nameField.controller?.text, 'Wallet 3');
    });

    testWidgets('import private key asks for chain without password input', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      final importTypeSheet = find.byType(BottomSheet);
      expect(importTypeSheet, findsOneWidget);
      expect(find.byKey(const Key('walletImportPage')), findsNothing);
      expect(
        find.descendant(of: importTypeSheet, matching: find.text('多链钱包')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: importTypeSheet,
          matching: find.text('EVM、Bitcoin、Tron、Solana 或 Sui 钱包'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('私钥钱包')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const Key('walletImportPage')), findsOneWidget);
      expect(find.text('EVM'), findsOneWidget);
      expect(find.text('Bitcoin'), findsOneWidget);
      expect(find.text('Solana'), findsOneWidget);
      expect(find.text('Sui'), findsOneWidget);
      expect(find.byKey(const Key('privateKeyInput')), findsNothing);
      expect(find.byKey(const Key('importWalletPasswordInput')), findsNothing);

      await tester.tap(find.text('Bitcoin'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privateKeyInput')), findsOneWidget);
      expect(
        find.text('支持 EVM hex、Bitcoin WIF/hex、Solana 私钥或 Sui suiprivkey'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, '粘贴'), findsOneWidget);
      expect(find.byKey(const Key('importWalletPasswordInput')), findsOneWidget);
    });

    testWidgets('import form actions are pinned and match management buttons', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(accounts: [account]);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      final importTypeSheet = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
      );
      await tester.pumpAndSettle();

      final cancelButton = find.widgetWithText(OutlinedButton, '取消');
      final importButton = find.widgetWithText(FilledButton, '导入钱包');
      final importButtonWidget = tester.widget<FilledButton>(importButton);

      expect(tester.getSize(cancelButton).height, 52);
      expect(tester.getSize(importButton).height, 52);
      expect(
        tester.getSize(cancelButton).height,
        tester.getSize(importButton).height,
      );
      expect(tester.getBottomLeft(cancelButton).dy, greaterThan(780));
      expect(tester.getBottomLeft(importButton).dy, greaterThan(780));
      expect(
        importButtonWidget.style?.shape?.resolve({}),
        const RoundedRectangleBorder(borderRadius: AppRadius.mediumBorder),
      );
    });

    testWidgets(
      'import page back returns to wallet management without picker',
      (tester) async {
        final repository = _FakeWalletRepository(accounts: [account]);

        await tester.pumpWidget(
          _walletApp(
            repository: repository,
            home: const WalletManagementPage(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('导入钱包'));
        await tester.pumpAndSettle();

        final importTypeSheet = find.byType(BottomSheet);
        await tester.tap(
          find.descendant(of: importTypeSheet, matching: find.text('助记词钱包')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('walletImportPage')), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('walletImportPage')), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Main Wallet'), findsOneWidget);
      },
    );

    testWidgets('import Bitcoin private key passes the Bitcoin chain', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account],
        importPrivateKeyError: const WalletError.invalidPrivateKey(),
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();
      final importTypeSheet = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('私钥钱包')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bitcoin'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('privateKeyInput')),
        'not-a-bitcoin-key',
      );
      await tester.enterText(
        find.byKey(const Key('importWalletPasswordInput')),
        'StrongPass-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, '导入钱包'));
      await tester.pumpAndSettle();

      expect(repository.importPrivateKeyCallCount, 1);
      expect(repository.lastImportedPrivateKey, 'not-a-bitcoin-key');
      expect(
        repository.lastImportedPrivateKeyChain,
        WalletPrivateKeyChain.bitcoin,
      );
    });

    testWidgets('import private key shows localized validation errors', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(
        accounts: [account],
        importPrivateKeyError: const WalletError.invalidPrivateKey(),
      );

      await tester.pumpWidget(
        _walletApp(repository: repository, home: const WalletManagementPage()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();
      final importTypeSheet = find.byType(BottomSheet);
      expect(importTypeSheet, findsOneWidget);
      expect(find.byKey(const Key('walletImportPage')), findsNothing);
      await tester.tap(
        find.descendant(of: importTypeSheet, matching: find.text('私钥钱包')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('walletImportPage')), findsOneWidget);
      await tester.tap(find.text('EVM'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('privateKeyInput')),
        'not-a-key',
      );
      await tester.enterText(
        find.byKey(const Key('importWalletPasswordInput')),
        'StrongPass-123',
      );
      await tester.tap(find.widgetWithText(FilledButton, '导入钱包'));
      await tester.pumpAndSettle();

      expect(repository.importPrivateKeyCallCount, 1);
      expect(repository.lastImportedPrivateKey, 'not-a-key');
      expect(find.text('私钥格式无效'), findsOneWidget);
      expect(find.text('操作失败，请稍后重试'), findsNothing);
    });
  });
}

Future<void> _openWalletActions(WidgetTester tester, String walletId) async {
  await tester.tap(find.byKey(Key('walletActions-$walletId')));
  await tester.pumpAndSettle();
}

Finder _walletCard(String walletName) {
  return find.ancestor(
    of: find.text(walletName),
    matching: find.byType(InkWell),
  );
}

Finder _selectedMarkerInsideWallet(String walletName) {
  return find.descendant(
    of: _walletCard(walletName),
    matching: find.text('当前'),
  );
}

Color _walletTileBorderColor(WidgetTester tester, String walletId) {
  final tile = find.byKey(Key('walletTile-$walletId'));
  final material = tester
      .widgetList<Material>(
        find.ancestor(of: tile, matching: find.byType(Material)),
      )
      .singleWhere((widget) => widget.shape is RoundedRectangleBorder);
  final shape = material.shape! as RoundedRectangleBorder;
  return shape.side.color;
}

TextSpan _addressTextSpanWithPlainText(
  WidgetTester tester,
  String plainText, {
  Finder? within,
}) {
  Finder scoped(Finder finder) {
    final scope = within;
    if (scope == null) {
      return finder;
    }
    return find.descendant(of: scope, matching: finder);
  }

  for (final widget in tester.widgetList<SelectableText>(
    scoped(find.byType(SelectableText, skipOffstage: false)),
  )) {
    final span = widget.textSpan;
    if (span is TextSpan && span.toPlainText() == plainText) {
      return span;
    }
    final data = widget.data;
    if (data == plainText) {
      return TextSpan(text: data, style: widget.style);
    }
  }

  for (final widget in tester.widgetList<Text>(
    scoped(find.byType(Text, skipOffstage: false)),
  )) {
    final span = widget.textSpan;
    if (span is TextSpan && span.toPlainText() == plainText) {
      return span;
    }
    final data = widget.data;
    if (data == plainText) {
      return TextSpan(text: data, style: widget.style);
    }
  }

  for (final widget in tester.widgetList<RichText>(
    scoped(find.byType(RichText, skipOffstage: false)),
  )) {
    final span = widget.text;
    if (span is TextSpan && span.toPlainText() == plainText) {
      return span;
    }
  }

  throw StateError('No address text span with $plainText');
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

final class _WalletManagementHost extends StatelessWidget {
  const _WalletManagementHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Home Screen'),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WalletManagementPage(),
                  ),
                );
              },
              child: const Text('Open Wallet Management'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _walletApp({
  required WalletRepository repository,
  required Widget home,
  ChainRepository? chainRepository,
  BiometricPasswordStore? biometricStore,
  ReceiveQrImageSaver? receiveQrImageSaver,
  bool unlockSession = true,
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      chainRepositoryProvider.overrideWithValue(
        chainRepository ?? _FakeChainRepository(),
      ),
      if (biometricStore != null)
        biometricPasswordStoreProvider.overrideWithValue(biometricStore),
      if (receiveQrImageSaver != null)
        receiveQrImageSaverProvider.overrideWithValue(receiveQrImageSaver),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: unlockSession ? _UnlockedWalletHarness(child: home) : home,
      ),
    ),
  );
}

final class _UnlockedWalletHarness extends ConsumerStatefulWidget {
  const _UnlockedWalletHarness({required this.child});

  final Widget child;

  @override
  ConsumerState<_UnlockedWalletHarness> createState() =>
      _UnlockedWalletHarnessState();
}

final class _UnlockedWalletHarnessState
    extends ConsumerState<_UnlockedWalletHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_unlock());
    });
  }

  Future<void> _unlock() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final wallet = wallets.firstOrNull;
    if (wallet == null) {
      return;
    }
    await ref
        .read(walletSessionControllerProvider.notifier)
        .unlock(walletId: wallet.id, password: 'test-password');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final class _FakeChainRepository implements ChainRepository {
  String selectedChainId = 'ethereum';

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
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

final class _FakeReceiveQrImageSaver implements ReceiveQrImageSaver {
  _FakeReceiveQrImageSaver({this.error, this.completer});

  final Object? error;
  final Completer<void>? completer;
  int saveCallCount = 0;
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<void> save(Uint8List bytes, {required String fileName}) async {
    saveCallCount += 1;
    savedBytes = bytes;
    savedFileName = fileName;
    if (error != null) {
      throw error!;
    }
    if (completer != null) {
      await completer!.future;
    }
  }
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({
    required List<WalletAccount> accounts,
    this.exportError,
    this.deleteError,
    this.importMnemonicError,
    this.importMnemonicCompleter,
    this.importPrivateKeyError,
  }) : _accounts = [...accounts];

  static const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  final List<WalletAccount> _accounts;
  final Object? exportError;
  final Object? deleteError;
  final Object? importMnemonicError;
  final Completer<WalletAccount>? importMnemonicCompleter;
  final Object? importPrivateKeyError;
  int exportCallCount = 0;
  String? lastExportPassword;
  String? deletedWalletId;
  String? lastDeletePassword;
  int changePasswordCallCount = 0;
  String? lastChangedWalletId;
  String? lastCurrentPassword;
  String? lastNewPassword;
  int createWalletCallCount = 0;
  String? lastCreateWalletName;
  String? lastCreateWalletPassword;
  int renameWalletCallCount = 0;
  String? lastRenamedWalletId;
  String? lastRenamedWalletName;
  int importMnemonicCallCount = 0;
  int importPrivateKeyCallCount = 0;
  String? lastImportedMnemonic;
  String? lastImportedPrivateKey;
  WalletPrivateKeyChain? lastImportedPrivateKeyChain;
  int unlockCallCount = 0;
  String? lastUnlockWalletId;
  String? lastUnlockPassword;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    createWalletCallCount += 1;
    lastCreateWalletName = name;
    lastCreateWalletPassword = password ?? '';
    final wallet = WalletAccount(
      id: 'wallet-created-$createWalletCallCount',
      name: name,
      evmAddress: '0x2222222222222222222222222222222222222222',
      solanaAddress: 'So22222222222222222222222222222222222222222',
      btcAddress: 'bc1q2222222222222222222222222222222222g3e3a',
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );
    _accounts.add(wallet);
    return wallet;
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    if (deleteError != null) {
      throw deleteError!;
    }
    deletedWalletId = walletId;
    lastDeletePassword = password;
    _accounts.removeWhere((account) => account.id == walletId);
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCallCount += 1;
    lastChangedWalletId = walletId;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async {
    exportCallCount += 1;
    lastExportPassword = password;
    if (exportError != null) {
      throw exportError!;
    }
    return switch (secretType) {
      WalletSecretType.mnemonic => mnemonic,
      WalletSecretType.evmPrivateKey => '0x1234',
      WalletSecretType.btcPrivateKey => 'btc1234',
      WalletSecretType.tronPrivateKey => 'tron1234',
      WalletSecretType.solanaPrivateKey => 'solana1234',
      WalletSecretType.suiPrivateKey =>
        'suiprivkey1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
    };
  }

  @override
  Future<List<WalletAccount>> getWallets() async =>
      List.unmodifiable(_accounts);

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async {
    importMnemonicCallCount += 1;
    lastImportedMnemonic = mnemonic;
    if (importMnemonicError != null) {
      throw importMnemonicError!;
    }
    if (importMnemonicCompleter != null) {
      return await importMnemonicCompleter!.future;
    }
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async {
    importPrivateKeyCallCount += 1;
    lastImportedPrivateKey = privateKey;
    lastImportedPrivateKeyChain = chain;
    if (importPrivateKeyError != null) {
      throw importPrivateKeyError!;
    }
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
  }) async {
    renameWalletCallCount += 1;
    lastRenamedWalletId = walletId;
    lastRenamedWalletName = name;
    final index = _accounts.indexWhere((account) => account.id == walletId);
    final previous = _accounts[index];
    final renamed = WalletAccount(
      id: previous.id,
      name: name,
      evmAddress: previous.evmAddress,
      solanaAddress: previous.solanaAddress,
      createdAt: previous.createdAt,
      updatedAt: previous.updatedAt,
    );
    _accounts[index] = renamed;
    return renamed;
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCallCount += 1;
    lastUnlockWalletId = walletId;
    lastUnlockPassword = password;
    final account = _accounts.firstWhere((item) => item.id == walletId);
    return WalletUnlockResult(account: account, walletDek: [1, 2, 3]);
  }
}

final class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.canAuthenticate,
    required this.authenticateResult,
  });

  final bool canAuthenticate;
  final bool authenticateResult;

  @override
  Future<bool> canAuthenticateWithBiometrics() async => canAuthenticate;

  @override
  Future<bool> authenticate({required String reason}) async {
    return authenticateResult;
  }
}

final class _FakeSecurePasswordStorage implements SecurePasswordStorage {
  String? password;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> savePassword(String password) async {
    this.password = password;
  }

  @override
  Future<void> deletePassword() async {
    password = null;
  }
}
