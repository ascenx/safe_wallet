import '../../chains/domain/chain_config.dart';
import 'dapp_request_controller.dart';

typedef DappRequestHandleCallback =
    Future<DappRequestResult> Function(
      DappRpcRequest request, {
      DappAuthorizationDecision? authorizationDecision,
      DappConfirmationDecision? confirmationDecision,
      String? signingPassword,
      bool rememberSigningPassword,
    });

typedef DappAuthorizationPrompt =
    Future<DappAuthorizationDecision> Function(
      DappRequestConfirmation confirmation,
    );

typedef DappConfirmationPrompt =
    Future<DappConfirmationDecision> Function(
      DappRequestConfirmation confirmation,
    );

typedef DappSigningPasswordPrompt =
    Future<({String password, bool rememberPassword})?> Function();

final class DappRequestCoordinator {
  const DappRequestCoordinator({
    required DappRequestHandleCallback handle,
    required DappAuthorizationPrompt showAuthorization,
    required DappConfirmationPrompt showConfirmation,
    required DappSigningPasswordPrompt requestSigningPassword,
  }) : _handle = handle,
       _showAuthorization = showAuthorization,
       _showConfirmation = showConfirmation,
       _requestSigningPassword = requestSigningPassword;

  final DappRequestHandleCallback _handle;
  final DappAuthorizationPrompt _showAuthorization;
  final DappConfirmationPrompt _showConfirmation;
  final DappSigningPasswordPrompt _requestSigningPassword;

  Future<DappRequestResult> process(DappRpcRequest request) async {
    var boundRequest = request;
    var result = await _handle(boundRequest);

    if (result.status == DappRequestResultStatus.authorizationRequired) {
      final authorization = result.confirmation;
      if (authorization == null) {
        return result;
      }
      boundRequest = _bindRequest(boundRequest, authorization);
      final decision = await _showAuthorization(authorization);
      result = await _handle(boundRequest, authorizationDecision: decision);
    }

    if (result.status != DappRequestResultStatus.confirmationRequired) {
      return result;
    }
    final confirmation = result.confirmation;
    if (confirmation == null) {
      return result;
    }
    boundRequest = _bindRequest(boundRequest, confirmation);
    final decision = await _showConfirmation(confirmation);
    result = await _handle(boundRequest, confirmationDecision: decision);

    if (decision != DappConfirmationDecision.approved ||
        !_needsSigningPasswordRetry(confirmation, result)) {
      return result;
    }
    final authorization = await _requestSigningPassword();
    if (authorization == null) {
      return const DappRequestResult.rejected();
    }
    return _handle(
      boundRequest,
      confirmationDecision: decision,
      signingPassword: authorization.password,
      rememberSigningPassword: authorization.rememberPassword,
    );
  }

  static DappRpcRequest _bindRequest(
    DappRpcRequest request,
    DappRequestConfirmation confirmation,
  ) {
    final chainId = _caipChainId(confirmation.chain);
    final address = confirmation.address.trim();
    if (chainId == null || address.isEmpty) {
      return request;
    }
    return request.copyWithExecutionContext(
      chainId: chainId,
      authorizedAddress: address,
    );
  }

  static String? _caipChainId(ChainConfig chain) {
    return switch (chain.chainType) {
      ChainType.evm => 'eip155:${chain.chainId}',
      ChainType.solana => switch (chain.chainId) {
        'mainnet-beta' => 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp',
        'devnet' => 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
        'testnet' => 'solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z',
        _ => null,
      },
      ChainType.sui =>
        chain.chainId.startsWith('sui:')
            ? chain.chainId
            : 'sui:${chain.chainId}',
      ChainType.bitcoin || ChainType.tron => null,
    };
  }

  static bool _needsSigningPasswordRetry(
    DappRequestConfirmation confirmation,
    DappRequestResult result,
  ) {
    if (result.status != DappRequestResultStatus.walletLocked) {
      return false;
    }
    return switch (confirmation.kind) {
      DappConfirmationKind.signature ||
      DappConfirmationKind.transaction => true,
      DappConfirmationKind.authorization ||
      DappConfirmationKind.chainSwitch => false,
    };
  }
}
