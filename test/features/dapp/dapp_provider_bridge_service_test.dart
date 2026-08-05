import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/data/dapp_provider_bridge_service.dart';

void main() {
  group('DappProviderBridgeService', () {
    final service = DappProviderBridgeService();

    test('parseRequest ignores malformed bridge messages', () {
      final request = service.parseRequest(
        message: 'not json',
        fallbackOrigin: 'https://app.uniswap.org',
      );

      expect(request, isNull);
    });

    test('parseRequest falls back to current WebView URL origin', () {
      final request = service.parseRequest(
        message:
            '{"id":1,"origin":"https://app.uniswap.org","method":"eth_chainId","params":[]}',
        fallbackOrigin: 'https://app.uniswap.org/swap',
      );

      expect(request?.id, 1);
      expect(request?.origin, 'https://app.uniswap.org');
      expect(request?.method, 'eth_chainId');
      expect(request?.params, isEmpty);
    });

    test('parseRequest rejects a claimed origin that differs from WebView', () {
      final request = service.parseRequest(
        message:
            '{"id":1,"origin":"https://trusted.example","method":"eth_accounts","params":[]}',
        fallbackOrigin: 'https://evil.example/drain',
      );

      expect(request, isNull);
    });

    test('parseRequest rejects oversized and deeply nested payloads', () {
      final oversized = jsonEncode({
        'id': 1,
        'origin': 'https://example.com',
        'method': 'personal_sign',
        'params': ['x' * (DappProviderBridgeService.maxMessageLength + 1)],
      });
      Object nested = 'leaf';
      for (
        var index = 0;
        index < DappProviderBridgeService.maxJsonDepth + 1;
        index += 1
      ) {
        nested = [nested];
      }
      final deeplyNested = jsonEncode({
        'id': 2,
        'origin': 'https://example.com',
        'method': 'personal_sign',
        'params': [nested],
      });

      expect(
        service.parseRequest(
          message: oversized,
          fallbackOrigin: 'https://example.com',
        ),
        isNull,
      );
      expect(
        service.parseRequest(
          message: deeplyNested,
          fallbackOrigin: 'https://example.com',
        ),
        isNull,
      );
    });

    test('secure bridge session binds proof to the top-level origin', () {
      final dynamic session = service.createSession();
      final script =
          session.providerScript(pageOrigin: 'https://trusted.example/app')
              as String;
      final proofLiteral = RegExp(
        r'window\.__safeWalletBridgeProof = ("[^"]+")',
      ).firstMatch(script)?.group(1);

      expect(proofLiteral, isNotNull);
      final proof = jsonDecode(proofLiteral!) as String;
      final valid = session.parseRequest(
        message: jsonEncode({
          'id': 1,
          'origin': 'https://trusted.example',
          'bridgeProof': proof,
          'method': 'eth_accounts',
          'params': <Object?>[],
        }),
        fallbackOrigin: 'https://trusted.example/app',
      );
      final missing = session.parseRequest(
        message: jsonEncode({
          'id': 2,
          'origin': 'https://trusted.example',
          'method': 'eth_accounts',
          'params': <Object?>[],
        }),
        fallbackOrigin: 'https://trusted.example/app',
      );
      final otherOriginScript =
          session.providerScript(pageOrigin: 'https://evil.example') as String;
      final otherProofLiteral = RegExp(
        r'window\.__safeWalletBridgeProof = ("[^"]+")',
      ).firstMatch(otherOriginScript)?.group(1);
      final otherProof = jsonDecode(otherProofLiteral!) as String;
      final crossOrigin = session.parseRequest(
        message: jsonEncode({
          'id': 3,
          'origin': 'https://trusted.example',
          'bridgeProof': otherProof,
          'method': 'eth_accounts',
          'params': <Object?>[],
        }),
        fallbackOrigin: 'https://trusted.example/app',
      );

      expect(valid, isNotNull);
      expect(missing, isNull);
      expect(crossOrigin, isNull);
    });

    test('providerScript supports EIP-1193 event listeners', () {
      final script = service.providerScript();

      expect(script, contains('var listeners = {};'));
      expect(script, contains('window.__safeWalletEmit'));
      expect(script, contains('on: function(event, handler)'));
      expect(script, contains('removeListener: function(event, handler)'));
    });

    test('providerScript refuses to install inside iframes', () {
      final script = service.providerScript();

      expect(script, contains('if (window.top !== window.self)'));
      expect(
        script.indexOf('if (window.top !== window.self)'),
        lessThan(script.indexOf('var callbacks = {};')),
      );
    });

    test('providerScript emits dApp bridge diagnostics to console', () {
      final script = service.providerScript();

      expect(script, contains('[SafeWalletDapp] provider installed'));
      expect(script, contains('[SafeWalletDapp] request'));
      expect(script, contains('[SafeWalletDapp] resolve error'));
      expect(script, contains('[SafeWalletDapp] resolve result'));
    });

    test('providerScript advertises an injected wallet to dApp connectors', () {
      final script = service.providerScript();

      expect(script, contains('eip6963:requestProvider'));
      expect(script, contains('eip6963:announceProvider'));
      expect(script, contains('isMetaMask: true'));
      expect(script, contains('_metamask'));
      expect(script, contains('enable: function()'));
      expect(script, contains('send: function('));
      expect(script, contains('sendAsync: function('));
      expect(script, contains('isConnected: function()'));
    });

    test('providerScript advertises the app logo as the wallet icon', () {
      final script = service.providerScript();
      final logoBytes = File('assets/common/logo.svg').readAsBytesSync();
      final expectedIcon =
          'data:image/svg+xml;base64,${base64Encode(logoBytes)}';

      expect(script, contains("icon: '$expectedIcon'"));
    });

    test('providerScript avoids Safe Apps connector fingerprint', () {
      final script = service.providerScript();

      expect(script, isNot(contains('isSafeWallet: true')));
      expect(script, isNot(contains('window.ethereum.isSafeWallet &&')));
      expect(script, isNot(contains('window.solana.isSafeWallet &&')));
      expect(script, isNot(contains("name: 'Safe Wallet'")));
      expect(script, contains('isSafeWalletDappProvider: true'));
      expect(script, contains('window.ethereum.isSafeWalletDappProvider'));
      expect(script, contains('window.solana.isSafeWalletDappProvider'));
      expect(script, contains("rdns: 'com.safewallet.mobile'"));
    });

    test('providerScript exposes wagmi compatible discovery fields', () {
      final script = service.providerScript(initialChainId: '0x1');

      expect(script, contains('provider.providers = [provider]'));
      expect(script, contains('window.ethereum.providers'));
      expect(script, contains('Object.freeze(providerInfo)'));
      expect(script, contains('Object.freeze({'));
      expect(script, contains("__safeWalletEmit('connect'"));
      expect(script, contains("chainId: provider.chainId"));
    });

    test('providerScript exposes Phantom compatible Solana provider', () {
      final script = service.providerScript(initialChainId: '0x1');

      expect(script, contains('var solanaProvider = {'));
      expect(script, contains('isPhantom: true'));
      expect(script, contains('connect: function(options)'));
      expect(script, contains('disconnect: function()'));
      expect(script, contains('signMessage: function(message, encoding)'));
      expect(script, contains('signTransaction: function(transaction)'));
      expect(script, contains('signAllTransactions: function(transactions)'));
      expect(
        script,
        contains('signAndSendTransaction: function(transaction, options)'),
      );
      expect(script, contains("method: 'solana_connect'"));
      expect(script, contains("method: 'solana_signTransaction'"));
      expect(script, contains("method: 'solana_signAndSendTransaction'"));
      expect(script, contains('window.phantom.solana = solanaProvider'));
      expect(script, contains('window.solana = solanaProvider'));
      expect(script, contains('window.__safeWalletMakeSolanaPublicKey'));
    });

    test('providerScript registers a Solana Wallet Standard wallet', () {
      final script = service.providerScript(initialChainId: '0x1');

      expect(script, contains('wallet-standard:register-wallet'));
      expect(script, contains('wallet-standard:app-ready'));
      expect(script, contains('var standardSolanaWallet = {'));
      expect(script, contains("version: '1.0.0'"));
      expect(script, contains("chains: ['solana:mainnet']"));
      expect(script, contains("'standard:connect'"));
      expect(script, contains("'standard:disconnect'"));
      expect(script, contains("'standard:events'"));
      expect(script, contains("'solana:signMessage'"));
      expect(script, contains("'solana:signTransaction'"));
      expect(script, contains("'solana:signAndSendTransaction'"));
      expect(script, contains('registerStandardSolanaWallet'));
    });

    test('providerScript registers a Sui Wallet Standard wallet', () {
      final script = service.providerScript(initialChainId: '0x1');

      expect(script, contains('var standardSuiWallet = {'));
      expect(
        script,
        contains("chains: ['sui:mainnet', 'sui:testnet', 'sui:devnet']"),
      );
      expect(script, contains("'standard:connect'"));
      expect(script, contains("'standard:disconnect'"));
      expect(script, contains("'standard:events'"));
      expect(script, contains("'sui:signPersonalMessage'"));
      expect(script, contains("'sui:signTransaction'"));
      expect(script, contains("'sui:signAndExecuteTransaction'"));
      expect(script, contains("method: 'sui_connect'"));
      expect(script, contains("method: 'sui_signPersonalMessage'"));
      expect(script, contains("method: 'sui_signTransaction'"));
      expect(script, contains("method: 'sui_signAndExecuteTransaction'"));
      expect(script, contains('publicKey: new Uint8Array'));
      expect(script, contains('registerStandardSuiWallet'));
    });

    test('providerScript re-registers Wallet Standard before early return', () {
      final script = service.providerScript(initialChainId: '0x1');

      expect(
        script,
        contains(
          'typeof window.__safeWalletRegisterStandardSolanaWallet === '
          "'function'",
        ),
      );
      expect(
        script,
        contains('window.__safeWalletRegisterStandardSolanaWallet();'),
      );
      expect(
        script,
        contains('window.__safeWalletRegisterStandardSolanaWallet ='),
      );
      expect(script, contains('registerStandardSolanaWallet;'));
      expect(
        script,
        contains(
          'typeof window.__safeWalletRegisterStandardSuiWallet === '
          "'function'",
        ),
      );
      expect(
        script,
        contains('window.__safeWalletRegisterStandardSuiWallet();'),
      );
    });

    test('callbackScript syncs selectedAddress after account responses', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://app.uniswap.org',
          method: 'eth_requestAccounts',
        ),
        result: const DappRequestResult.success([
          '0x1111111111111111111111111111111111111111',
        ]),
      );

      expect(script, contains('selectedAddress'));
      expect(script, contains('accountsChanged'));
      expect(script, contains('0x1111111111111111111111111111111111111111'));
    });

    test('callbackScript syncs selectedAddress after permission responses', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://app.uniswap.org',
          method: 'wallet_requestPermissions',
        ),
        result: const DappRequestResult.success([
          {
            'parentCapability': 'eth_accounts',
            'caveats': [
              {
                'type': 'restrictReturnedAccounts',
                'value': ['0x1111111111111111111111111111111111111111'],
              },
            ],
          },
        ]),
      );

      expect(script, contains('selectedAddress'));
      expect(script, contains('accountsChanged'));
      expect(script, contains('restrictReturnedAccounts'));
      expect(script, contains('0x1111111111111111111111111111111111111111'));
    });

    test('callbackScript emits chainChanged after approved chain switch', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://app.uniswap.org',
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0x38'},
          ],
        ),
        result: const DappRequestResult.success(null),
      );

      expect(script, contains('chainChanged'));
      expect(script, contains('0x38'));
    });

    test('callbackScript preserves upstream JSON-RPC errors', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://pancakeswap.finance',
          method: 'eth_call',
        ),
        result: const DappRequestResult.jsonRpcError(
          DappJsonRpcError(
            code: -32000,
            message: 'err: insufficient funds for gas * price + value',
          ),
        ),
      );

      expect(script, contains('"code":-32000'));
      expect(
        script,
        contains('err: insufficient funds for gas * price + value'),
      );
      expect(script, isNot(contains('dapp_request_failed')));
    });

    test('callbackScript does not emit chainChanged for chain id queries', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://app.uniswap.org',
          method: 'eth_chainId',
        ),
        result: const DappRequestResult.success('0x1'),
      );

      expect(script, contains('chainId = response.result'));
      expect(script, isNot(contains('chainChanged')));
    });

    test('callbackScript syncs Solana public key after connect', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://jup.ag',
          method: 'solana_connect',
        ),
        result: const DappRequestResult.success({
          'publicKey': '11111111111111111111111111111111',
        }),
      );

      expect(script, contains('window.solana.publicKey'));
      expect(script, contains('window.solana.isConnected = true'));
      expect(script, contains('window.__safeWalletSetStandardSolanaAccount'));
      expect(script, contains("__safeWalletEmitSolana('connect'"));
      expect(script, contains('11111111111111111111111111111111'));
    });

    test('callbackScript converts Solana message signatures to Uint8Array', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://jup.ag',
          method: 'solana_signMessage',
        ),
        result: const DappRequestResult.success({
          'signature': [1, 2, 3],
          'publicKey': '11111111111111111111111111111111',
        }),
      );

      expect(script, contains('new Uint8Array(response.result.signature)'));
      expect(script, contains('response.result.publicKey'));
      expect(script, contains('11111111111111111111111111111111'));
    });

    test('callbackScript updates Sui Wallet Standard account after connect', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://trade.sui.io',
          method: 'sui_connect',
        ),
        result: const DappRequestResult.success({
          'address':
              '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
          'publicKey': [1, 2, 3],
          'chain': 'sui:mainnet',
        }),
      );

      expect(script, contains('window.__safeWalletSetStandardSuiAccount'));
      expect(script, contains('new Uint8Array(response.result.publicKey)'));
      expect(script, contains('sui:mainnet'));
    });

    test('callbackScript clears Sui Wallet Standard account on disconnect', () {
      final script = service.callbackScript(
        request: const DappRpcRequest(
          id: 1,
          origin: 'https://trade.sui.io',
          method: 'sui_disconnect',
        ),
        result: const DappRequestResult.success(null),
      );

      expect(script, contains('__safeWalletSetStandardSuiAccount(null'));
    });
  });
}
