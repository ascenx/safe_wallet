import 'dart:async';
import 'dart:io';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('dApp WebView smoke', () {
    late _DappTestServer server;

    setUp(() async {
      server = await _DappTestServer.start();
    });

    tearDown(() async {
      await server.close();
    });

    testWidgets('approves account request and rejects signature through bridge',
        (tester) async {
      LocaleSettings.setLocaleSync(AppLocale.zh);
      final account = _account();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dappPermissionRepositoryProvider.overrideWithValue(
              InMemoryDappPermissionRepository(),
            ),
            walletRepositoryProvider.overrideWithValue(
              _FakeWalletRepository(account: account),
            ),
            chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: DappBrowserPage(initialUrl: server.url),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DappBrowserPage)),
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container.read(walletSessionControllerProvider.notifier).unlock(
            walletId: account.id,
            password: 'password',
            now: DateTime.utc(2026, 6, 6, 12),
          );

      expect(
        await tester.runAsync(() => server.waitFor('provider')),
        'true',
      );

      await _tapVisibleText(tester, '批准', after: find.text('连接 dApp'));

      expect(
        await tester.runAsync(() => server.waitFor('accounts')),
        '["${account.evmAddress}"]',
      );

      await _tapVisibleText(tester, '拒绝', after: find.text('确认签名'));

      expect(
        await tester.runAsync(() => server.waitFor('signatureError')),
        '4001:dapp_user_rejected',
      );
    });
  });
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

Future<void> _tapVisibleText(
  WidgetTester tester,
  String text, {
  required Finder after,
}) async {
  final finder = find.text(text);
  await _pumpUntilFound(tester, after, maxPumps: 160);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 100));
}

final class _DappTestServer {
  _DappTestServer._(this._server);

  final HttpServer _server;
  final Map<String, List<String>> _events = {};
  final Map<String, List<Completer<String>>> _waiters = {};

  String get url => 'http://127.0.0.1:${_server.port}/';

  static Future<_DappTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final testServer = _DappTestServer._(server);
    server.listen(testServer._handleRequest);
    return testServer;
  }

  Future<String> waitFor(String name) {
    final values = _events[name];
    if (values != null && values.isNotEmpty) {
      return Future.value(values.removeAt(0));
    }

    final completer = Completer<String>();
    _waiters.putIfAbsent(name, () => []).add(completer);
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Timed out waiting for $name'),
    );
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  void _handleRequest(HttpRequest request) {
    if (request.uri.path == '/record') {
      _record(
        request.uri.queryParameters['name'] ?? '',
        request.uri.queryParameters['value'] ?? '',
      );
      request.response.statusCode = HttpStatus.noContent;
      unawaited(request.response.close());
      return;
    }

    request.response.headers.contentType = ContentType.html;
    request.response.write(_html);
    unawaited(request.response.close());
  }

  void _record(String name, String value) {
    if (name.isEmpty) {
      return;
    }
    final waiters = _waiters[name];
    if (waiters != null && waiters.isNotEmpty) {
      waiters.removeAt(0).complete(value);
      return;
    }
    _events.putIfAbsent(name, () => []).add(value);
  }
}

const _html = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Safe Wallet dApp Test</title>
</head>
<body>
  <main>Safe Wallet dApp Test</main>
  <script>
    (function() {
      function record(name, value) {
        fetch(
          '/record?name=' + encodeURIComponent(name) +
          '&value=' + encodeURIComponent(String(value)),
          { cache: 'no-store' }
        ).catch(function() {});
      }

      function asValue(value) {
        try {
          return JSON.stringify(value);
        } catch (error) {
          return String(value);
        }
      }

      function waitEthereum() {
        if (window.ethereum && window.ethereum.isSafeWallet) {
          return Promise.resolve();
        }
        return new Promise(function(resolve) {
          window.addEventListener('ethereum#initialized', resolve, {
            once: true
          });
          setTimeout(resolve, 5000);
        });
      }

      window.addEventListener('load', async function() {
        await waitEthereum();
        record(
          'provider',
          window.ethereum && window.ethereum.isSafeWallet ? 'true' : 'false'
        );
        try {
          var accounts = await window.ethereum.request({
            method: 'eth_requestAccounts'
          });
          record('accounts', asValue(accounts));
          try {
            await window.ethereum.request({
              method: 'personal_sign',
              params: ['safe wallet integration message', accounts[0]]
            });
            record('signature', 'approved');
          } catch (error) {
            record(
              'signatureError',
              String(error && error.code) + ':' +
                String(error && error.message)
            );
          }
        } catch (error) {
          record(
            'accountsError',
            String(error && error.code) + ':' +
              String(error && error.message)
          );
        }
      });
    })();
  </script>
</body>
</html>
''';

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
    return defaultChains.firstWhere((chain) => chain.id == chainId);
  }
}
