part of 'dapp_request_controller.dart';

extension _DappSuiRequestHandler on DappRequestController {
  Future<DappRequestResult> _connectSui(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DateTime now,
  }) async {
    final context = await _suiContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    final existing = await _permissionForSui(request.domain, context, now);
    if (existing == null) {
      if (authorizationDecision == null) {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.suiAddress,
          ),
        );
      }
      if (authorizationDecision == DappAuthorizationDecision.rejected) {
        return const DappRequestResult.rejected();
      }
      await _requestRef
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: request.domain,
            walletId: context.account.id,
            chainId: context.chain.chainId,
            address: context.account.suiAddress,
            now: now,
            persistent: _isPersistentAuthorization(authorizationDecision),
          );
    } else {
      await _touchSui(request.domain, context, now);
    }
    return DappRequestResult.success({
      'address': context.account.suiAddress,
      'publicKey': base64Decode(context.account.suiPublicKey),
      'chain': context.chain.chainId,
    });
  }

  Future<DappRequestResult> _disconnectSui(
    DappRpcRequest request, {
    required DateTime now,
  }) async {
    final context = await _suiContext(request);
    if (context == null) {
      return const DappRequestResult.success(null);
    }
    final permission = await _permissionForSui(request.domain, context, now);
    if (permission != null) {
      await _requestRef
          .read(dappPermissionControllerProvider.notifier)
          .revoke(permission.id);
    }
    return const DappRequestResult.success(null);
  }

  Future<DappRequestResult> _signSuiPersonalMessage(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _suiContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    final permission = await _ensureSuiPermission(
      request,
      context,
      authorizationDecision: authorizationDecision,
      now: now,
    );
    if (permission.result != null) {
      return permission.result!;
    }
    final payload = _firstMap(request.params);
    if (payload == null || !_matchesSuiRequest(payload, context)) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    final message = _suiBytesField(
      payload['message'],
      maximumLength: _maximumSuiMessageBytes,
    );
    if (message == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.signature,
          domain: request.domain,
          chain: context.chain,
          address: context.account.suiAddress,
          message: _readableBytes(message),
          rawMessage: base64Encode(message),
        ),
      );
    }
    if (confirmationDecision == DappConfirmationDecision.rejected) {
      return const DappRequestResult.rejected();
    }
    final keyMaterial = await _readSigningKeyMaterial(
      context.account.id,
      now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    final privateKey = keyMaterial?.suiPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.walletLocked();
    }
    final signed = await _requestRef
        .read(dappSuiSignerProvider)
        .signPersonalMessage(privateKey: privateKey, message: message);
    await _recordSignature(
      SecurityLogEventType.signMessage,
      account: context.account,
      chain: context.chain,
    );
    await _touchSui(request.domain, context, now);
    return DappRequestResult.success({
      'bytes': signed.bytes,
      'signature': signed.signature,
    });
  }

  Future<DappRequestResult> _signSuiTransaction(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required bool execute,
    required DateTime now,
  }) async {
    final context = await _suiContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    final permission = await _ensureSuiPermission(
      request,
      context,
      authorizationDecision: authorizationDecision,
      now: now,
    );
    if (permission.result != null) {
      return permission.result!;
    }
    final payload = _firstMap(request.params);
    if (payload == null || !_matchesSuiRequest(payload, context)) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    final transactionBytes = _suiBytesField(
      payload['transaction'],
      maximumLength: _maximumSuiTransactionBytes,
    );
    if (transactionBytes == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final preview = _requestRef
        .read(dappTransactionPreviewerProvider)
        .previewSui(
          transactionBytes: transactionBytes,
          expectedSender: context.account.suiAddress,
        );
    if (preview == null) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.transaction,
          domain: request.domain,
          chain: context.chain,
          address: context.account.suiAddress,
          transaction: preview,
        ),
      );
    }
    if (confirmationDecision == DappConfirmationDecision.rejected) {
      return const DappRequestResult.rejected();
    }
    final keyMaterial = await _readSigningKeyMaterial(
      context.account.id,
      now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    final privateKey = keyMaterial?.suiPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.walletLocked();
    }
    final signed = await _requestRef
        .read(dappSuiSignerProvider)
        .signTransaction(
          privateKey: privateKey,
          transactionBytes: transactionBytes,
        );
    await _recordSignature(
      SecurityLogEventType.signTransaction,
      account: context.account,
      chain: context.chain,
    );
    await _touchSui(request.domain, context, now);
    if (!execute) {
      return DappRequestResult.success({
        'bytes': signed.bytes,
        'signature': signed.signature,
      });
    }
    final rpcNode = await _requestRef.read(
      selectedResolvedRpcNodeProvider(context.chain).future,
    );
    final digest = await _requestRef
        .read(dappSuiTransactionExecutorProvider)
        .execute(
          chain: context.chain,
          rpcUrl: rpcNode.endpointUrl,
          transactionBytes: transactionBytes,
          signature: signed.signature,
          headers: rpcNode.endpointHeaders,
        );
    await _recordBroadcastTransaction(
      idPrefix: 'dapp-sui',
      chain: context.chain,
      account: context.account,
      transactionHash: digest,
      amount: '0',
      memo: request.method,
      now: now,
    );
    return DappRequestResult.success({'digest': digest});
  }

  Future<({DappPermission? permission, DappRequestResult? result})>
  _ensureSuiPermission(
    DappRpcRequest request,
    _DappSuiContext context, {
    required DappAuthorizationDecision? authorizationDecision,
    required DateTime now,
  }) async {
    var permission = await _permissionForSui(request.domain, context, now);
    if (permission != null) {
      return (permission: permission, result: null);
    }
    if (authorizationDecision == DappAuthorizationDecision.rejected) {
      return (permission: null, result: const DappRequestResult.rejected());
    }
    if (authorizationDecision == null) {
      return (
        permission: null,
        result: DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.suiAddress,
          ),
        ),
      );
    }
    permission = await _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .approve(
          domain: request.domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          address: context.account.suiAddress,
          now: now,
          persistent: _isPersistentAuthorization(authorizationDecision),
        );
    return (permission: permission, result: null);
  }

  Future<_DappSuiContext?> _suiContext(DappRpcRequest request) async {
    final chain = await _suiChain(request);
    if (chain == null) {
      return null;
    }
    final wallets = await _requestRef
        .read(walletRepositoryProvider)
        .getWallets();
    final account = _accountForRequest(
      request: request,
      wallets: wallets,
      matchesAuthorizedAddress: (wallet, address) =>
          normalizeSuiAddressInput(wallet.suiAddress) ==
          normalizeSuiAddressInput(address),
    );
    if (account == null ||
        account.suiAddress.isEmpty ||
        account.suiPublicKey.isEmpty) {
      return null;
    }
    try {
      if (base64Decode(account.suiPublicKey).length != 32) {
        return null;
      }
    } on FormatException {
      return null;
    }
    return _DappSuiContext(account: account, chain: chain);
  }

  Future<ChainConfig?> _suiChain(DappRpcRequest request) async {
    final requestChainId = request.chainId;
    if (requestChainId != null) {
      final reference = _caipReference(requestChainId, 'sui');
      if (reference == null) {
        return null;
      }
      final chains = await _requestRef.read(availableChainsProvider.future);
      return _firstWhereOrNull<ChainConfig>(
        chains,
        (chain) =>
            chain.chainType == ChainType.sui &&
            (chain.chainId == reference || chain.chainId == 'sui:$reference'),
      );
    }
    final selectedChain = await _requestRef.read(
      selectedChainControllerProvider.future,
    );
    if (selectedChain.chainType == ChainType.sui) {
      return selectedChain;
    }
    final chains = await _requestRef.read(availableChainsProvider.future);
    return _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) =>
              chain.chainType == ChainType.sui && chain.id == 'sui-mainnet',
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.sui && !chain.isTestnet,
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.sui,
        );
  }

  Future<DappPermission?> _permissionForSui(
    String domain,
    _DappSuiContext context,
    DateTime now,
  ) {
    return _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .permissionFor(
          domain: domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          now: now,
        );
  }

  Future<void> _touchSui(
    String domain,
    _DappSuiContext context,
    DateTime now,
  ) async {
    await _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .touch(
          domain: domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          now: now,
        );
  }
}

final class _DappSuiContext {
  const _DappSuiContext({required this.account, required this.chain});

  final WalletAccount account;
  final ChainConfig chain;
}
