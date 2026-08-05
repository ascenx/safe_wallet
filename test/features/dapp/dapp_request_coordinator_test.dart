import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_coordinator.dart';

void main() {
  const request = DappRpcRequest(
    origin: 'https://example.com',
    method: 'personal_sign',
  );
  const confirmation = DappRequestConfirmation(
    kind: DappConfirmationKind.signature,
    domain: 'example.com',
    chain: _chain,
    address: '0xabc',
  );

  test('coordinates authorization, confirmation, and password retry', () async {
    final calls =
        <
          ({
            DappAuthorizationDecision? authorization,
            DappConfirmationDecision? confirmation,
            String? password,
          })
        >[];
    final results = <DappRequestResult>[
      const DappRequestResult.authorizationRequired(confirmation),
      const DappRequestResult.confirmationRequired(confirmation),
      const DappRequestResult.walletLocked(),
      const DappRequestResult.success('0xsigned'),
    ];
    final coordinator = DappRequestCoordinator(
      handle:
          (
            _, {
            authorizationDecision,
            confirmationDecision,
            signingPassword,
            rememberSigningPassword = true,
          }) async {
            calls.add((
              authorization: authorizationDecision,
              confirmation: confirmationDecision,
              password: signingPassword,
            ));
            return results.removeAt(0);
          },
      showAuthorization: (_) async => DappAuthorizationDecision.approved,
      showConfirmation: (_) async => DappConfirmationDecision.approved,
      requestSigningPassword: () async =>
          (password: 'password', rememberPassword: false),
    );

    final result = await coordinator.process(request);

    expect(result.value, '0xsigned');
    expect(calls, [
      (authorization: null, confirmation: null, password: null),
      (
        authorization: DappAuthorizationDecision.approved,
        confirmation: null,
        password: null,
      ),
      (
        authorization: null,
        confirmation: DappConfirmationDecision.approved,
        password: null,
      ),
      (
        authorization: null,
        confirmation: DappConfirmationDecision.approved,
        password: 'password',
      ),
    ]);
  });

  test(
    'password cancellation rejects instead of leaving request pending',
    () async {
      final results = <DappRequestResult>[
        const DappRequestResult.confirmationRequired(confirmation),
        const DappRequestResult.walletLocked(),
      ];
      final coordinator = DappRequestCoordinator(
        handle:
            (
              _, {
              authorizationDecision,
              confirmationDecision,
              signingPassword,
              rememberSigningPassword = true,
            }) async => results.removeAt(0),
        showAuthorization: (_) async => DappAuthorizationDecision.rejected,
        showConfirmation: (_) async => DappConfirmationDecision.approved,
        requestSigningPassword: () async => null,
      );

      final result = await coordinator.process(request);

      expect(result.status, DappRequestResultStatus.rejected);
    },
  );

  test('does not ask for password after rejecting confirmation', () async {
    var passwordRequests = 0;
    final coordinator = DappRequestCoordinator(
      handle:
          (
            _, {
            authorizationDecision,
            confirmationDecision,
            signingPassword,
            rememberSigningPassword = true,
          }) async {
            if (confirmationDecision == null) {
              return const DappRequestResult.confirmationRequired(confirmation);
            }
            return const DappRequestResult.rejected();
          },
      showAuthorization: (_) async => DappAuthorizationDecision.rejected,
      showConfirmation: (_) async => DappConfirmationDecision.rejected,
      requestSigningPassword: () async {
        passwordRequests += 1;
        return (password: 'password', rememberPassword: true);
      },
    );

    final result = await coordinator.process(request);

    expect(result.status, DappRequestResultStatus.rejected);
    expect(passwordRequests, 0);
  });

  test('binds the confirmed chain and address across retries', () async {
    final observedRequests = <DappRpcRequest>[];
    var callCount = 0;
    final coordinator = DappRequestCoordinator(
      handle:
          (
            request, {
            authorizationDecision,
            confirmationDecision,
            signingPassword,
            rememberSigningPassword = true,
          }) async {
            observedRequests.add(request);
            callCount += 1;
            if (callCount == 1) {
              return const DappRequestResult.confirmationRequired(confirmation);
            }
            return const DappRequestResult.success('0xsigned');
          },
      showAuthorization: (_) async => DappAuthorizationDecision.rejected,
      showConfirmation: (_) async => DappConfirmationDecision.approved,
      requestSigningPassword: () async => null,
    );

    await coordinator.process(request);

    expect(observedRequests, hasLength(2));
    expect(observedRequests.first.chainId, isNull);
    expect(observedRequests.last.chainId, 'eip155:1');
    expect(observedRequests.last.authorizedAddress, '0xabc');
  });
}

const _chain = ChainConfig(
  id: 'ethereum',
  chainType: ChainType.evm,
  name: 'Ethereum',
  chainId: '1',
  symbol: 'ETH',
  rpcUrls: [],
  blockExplorerUrl: null,
  isTestnet: false,
);
