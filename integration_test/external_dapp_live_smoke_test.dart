import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safe_wallet/features/browser/presentation/dapp_browser_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('external live dApp smoke', () {
    testWidgets(
      'approves connect and rejects signature on MetaMask test dapp',
      (tester) async {
        if (!_liveExternalDappEnabled) {
          fail('Set SAFE_WALLET_LIVE_EXTERNAL_DAPP=true to run this smoke.');
        }
        LocaleSettings.setLocaleSync(AppLocale.zh);
        final account = _account();
        final repository = InMemoryDappPermissionRepository();
        final controllerCompleter = Completer<WebViewController>();
        final firstPageFinished = Completer<String>();

        final container = ProviderContainer(
          overrides: [
            dappPermissionRepositoryProvider.overrideWithValue(repository),
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository(account: account),
            ),
            chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
          ],
        );
        addTearDown(container.dispose);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container.read(walletSessionControllerProvider.notifier).unlock(
              walletId: account.id,
              password: 'password',
              now: DateTime.utc(2026, 6, 6, 12),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TranslationProvider(
              child: MaterialApp(
                theme: buildAppTheme(),
                home: DappBrowserPage(
                  initialUrl: _liveDappUrl,
                  onControllerCreated: controllerCompleter.complete,
                  onPageFinished: (url) {
                    if (!firstPageFinished.isCompleted) {
                      firstPageFinished.complete(url);
                    }
                  },
                ),
              ),
            ),
          ),
        );
        final controller = await tester.runAsync(() async {
          await firstPageFinished.future.timeout(const Duration(seconds: 60));
          return controllerCompleter.future.timeout(
            const Duration(seconds: 10),
          );
        });
        if (controller == null) {
          fail('WebView controller was not exposed to the smoke test.');
        }
        await controller.runJavaScript(
          "window.ethereum.request({method: 'eth_requestAccounts'});",
        );

        await _tapVisibleText(
          tester,
          '批准',
          after: find.text('连接 dApp'),
        );
        await tester.runAsync(() async {
          await _waitForPermission(repository, account);
        });

        await controller.runJavaScript(
          'window.ethereum.request({'
          "method: 'personal_sign', "
          'params: ${jsonEncode([
                'safe wallet external dapp smoke',
                account.evmAddress,
              ])}'
          '}).catch(function() {});',
        );

        await _tapVisibleText(
          tester,
          '拒绝',
          after: find.text('确认签名'),
        );
        await _pumpUntilGone(tester, find.text('确认签名'));
      },
      skip: !_liveExternalDappEnabled,
      timeout: const Timeout(Duration(seconds: 180)),
    );
  });
}

const _liveExternalDappEnabled =
    bool.hasEnvironment('SAFE_WALLET_LIVE_EXTERNAL_DAPP')
        ? bool.fromEnvironment('SAFE_WALLET_LIVE_EXTERNAL_DAPP')
        : false;
const _expectedDomain = 'metamask.github.io';
const _liveDappUrl = 'https://metamask.github.io/test-dapp/';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 240,
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
  fail('Timed out waiting for $finder to disappear.');
}

Future<void> _tapVisibleText(
  WidgetTester tester,
  String text, {
  required Finder after,
}) async {
  final finder = find.text(text);
  await _pumpUntilFound(tester, after);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _waitForPermission(
  DappPermissionRepository repository,
  WalletAccount account,
) async {
  for (var i = 0; i < 80; i += 1) {
    final permission = await repository.permissionFor(
      domain: _expectedDomain,
      walletId: account.id,
      chainId: '1',
    );
    if (permission?.address.toLowerCase() == account.evmAddress.toLowerCase()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $_expectedDomain permission.');
}

WalletAccount _account() {
  final now = DateTime.utc(2026, 6, 6, 12);
  return WalletAccount(
    id: 'wallet-1',
    name: 'Main Wallet',
    evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: now,
    updatedAt: now,
  );
}

final class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository({required this.account});

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
  }) async =>
      WalletKeyMaterial(
        evmPrivateKey:
            '1111111111111111111111111111111111111111111111111111111111111111',
      );

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
  }) async =>
      WalletUnlockResult(account: account, walletDek: [1, 2, 3, 4]);
}

final class _FakeChainRepository implements ChainRepository {
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
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == 'ethereum');
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    return defaultChains.firstWhere((chain) => chain.chainId == chainId);
  }
}
