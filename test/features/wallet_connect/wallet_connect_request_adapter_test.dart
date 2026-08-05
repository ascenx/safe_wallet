import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_request_adapter.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';

void main() {
  final request = WalletConnectRequest(
    id: 7,
    topic: 'topic-a',
    chain: const Caip2ChainId(namespace: 'eip155', reference: '56'),
    method: 'eth_sendTransaction',
    params: const {'from': '0xabc'},
    peer: const WalletConnectPeerMetadata(
      name: 'Example',
      description: '',
      url: 'https://example.com',
      icons: [],
    ),
    expiry: DateTime.utc(2030),
  );

  test('maps WalletConnect context and wraps map params for dApp core', () {
    final mapped = walletConnectDappRequest(request);

    expect(mapped.id, 7);
    expect(mapped.source, DappRequestSource.walletConnect);
    expect(mapped.chainId, 'eip155:56');
    expect(mapped.requestTopic, 'topic-a');
    expect(mapped.params, [
      const {'from': '0xabc'},
    ]);
  });

  test('maps success and JSON-RPC errors without leaking internal codes', () {
    expect(
      walletConnectResponse(
        request,
        const DappRequestResult.success('0xresult'),
      ).result,
      '0xresult',
    );
    final rejected = walletConnectResponse(
      request,
      const DappRequestResult.rejected(),
    );
    expect(rejected.error?.code, 5000);
    expect(rejected.error?.message, 'User rejected the request');

    final rpcError = walletConnectResponse(
      request,
      const DappRequestResult.jsonRpcError(
        DappJsonRpcError(code: -32000, message: 'execution reverted'),
      ),
    );
    expect(rpcError.error?.code, -32000);
    expect(rpcError.error?.message, 'execution reverted');
  });

  test(
    'validates the session namespace, chain, method, and current account',
    () {
      final valid = validateWalletConnectRequest(
        request: request,
        session: WalletConnectSession(
          topic: 'topic-a',
          pairingTopic: 'pairing-a',
          peer: request.peer,
          namespaces: {
            'eip155': WalletConnectApprovedNamespace(
              chains: {request.chain},
              methods: const {'eth_sendTransaction'},
              events: const {},
              accounts: {
                Caip10AccountId(chain: request.chain, address: '0xAbC'),
              },
            ),
          },
          expiry: DateTime.utc(2030),
          createdAt: DateTime.utc(2026),
        ),
        accountAddress: '0xabc',
        now: DateTime.utc(2026),
      );
      expect(valid, WalletConnectRequestValidation.valid);

      expect(
        validateWalletConnectRequest(
          request: request,
          session: WalletConnectSession(
            topic: 'other-topic',
            pairingTopic: 'pairing-a',
            peer: request.peer,
            namespaces: const {},
            expiry: DateTime.utc(2030),
            createdAt: DateTime.utc(2026),
          ),
          accountAddress: '0xabc',
          now: DateTime.utc(2026),
        ),
        WalletConnectRequestValidation.invalidSession,
      );
    },
  );

  test('rejects requests flagged by Verify Context', () {
    final unsafeRequest = WalletConnectRequest(
      id: request.id,
      topic: request.topic,
      chain: request.chain,
      method: request.method,
      params: request.params,
      peer: request.peer,
      expiry: request.expiry,
      verifyContext: const WalletConnectVerifyContext(
        origin: 'https://phishing.example',
        status: WalletConnectVerifyStatus.scam,
      ),
    );
    final session = WalletConnectSession(
      topic: request.topic,
      pairingTopic: 'pairing-a',
      peer: request.peer,
      namespaces: {
        'eip155': WalletConnectApprovedNamespace(
          chains: {request.chain},
          methods: {request.method},
          events: const {},
          accounts: {Caip10AccountId(chain: request.chain, address: '0xabc')},
        ),
      },
      expiry: DateTime.utc(2030),
      createdAt: DateTime.utc(2026),
    );

    expect(
      validateWalletConnectRequest(
        request: unsafeRequest,
        session: session,
        accountAddress: '0xabc',
        now: DateTime.utc(2026),
      ),
      WalletConnectRequestValidation.unsafeOrigin,
    );
    expect(
      walletConnectValidationError(
        unsafeRequest,
        WalletConnectRequestValidation.unsafeOrigin,
      ).error?.code,
      5100,
    );
  });
}
