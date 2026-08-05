part of 'dapp_request_controller.dart';

extension _DappEvmRequestHandler on DappRequestController {
  Future<DappRequestResult> _requestAccounts(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.success([]);
    }

    final existing = await _permissionFor(request, context, now);
    if (existing != null) {
      await _touch(request, context, now);
      return DappRequestResult.success([existing.address]);
    }

    if (authorizationDecision == null) {
      return DappRequestResult.authorizationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.authorization,
          domain: request.domain,
          chain: context.chain,
          address: context.account.evmAddress,
        ),
      );
    }

    if (authorizationDecision == DappAuthorizationDecision.rejected) {
      return const DappRequestResult.rejected();
    }

    final permission = await _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .approve(
          domain: request.domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          address: context.account.evmAddress,
          now: now,
          persistent: _isPersistentAuthorization(authorizationDecision),
        );
    return DappRequestResult.success([permission.address]);
  }

  Future<DappRequestResult> _requestPermissions(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DateTime now,
  }) async {
    if (!_requestsEthAccountsPermission(request.params)) {
      return const DappRequestResult.unsupported('wallet_requestPermissions');
    }

    final accountsResult = await _requestAccounts(
      request,
      authorizationDecision: authorizationDecision,
      now: now,
    );
    if (!accountsResult.isSuccess) {
      return accountsResult;
    }

    final accounts = accountsResult.value;
    if (accounts is! List) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    return DappRequestResult.success(
      _ethAccountsPermissions(accounts.whereType<String>()),
    );
  }

  Future<DappRequestResult> _getPermissions(
    DappRpcRequest request, {
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.success([]);
    }
    final permission = await _permissionFor(request, context, now);
    if (permission == null) {
      return const DappRequestResult.success([]);
    }
    await _touch(request, context, now);
    return DappRequestResult.success(
      _ethAccountsPermissions([permission.address]),
    );
  }

  Future<DappRequestResult> _accounts(
    DappRpcRequest request, {
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.success([]);
    }
    final permission = await _permissionFor(request, context, now);
    if (permission == null) {
      return const DappRequestResult.success([]);
    }
    await _touch(request, context, now);
    return DappRequestResult.success([permission.address]);
  }

  Future<DappRequestResult> _chainId(DappRpcRequest request) async {
    final chain = await _evmChain(request);
    if (chain == null) {
      return const DappRequestResult.failure('unsupported_chain');
    }
    return DappRequestResult.success(_chainIdToHex(chain.chainId));
  }

  Future<DappRequestResult> _netVersion(DappRpcRequest request) async {
    final chain = await _evmChain(request);
    if (chain == null) {
      return const DappRequestResult.failure('unsupported_chain');
    }
    return DappRequestResult.success(chain.chainId);
  }

  Future<DappRequestResult> _readEvmRpc(DappRpcRequest request) async {
    final chain = await _evmChain(request);
    if (chain == null) {
      return const DappRequestResult.failure('unsupported_chain');
    }
    final rpcNode = await _requestRef.read(
      selectedResolvedRpcNodeProvider(chain).future,
    );
    final response = await _requestRef
        .read(dappEvmReadRpcClientProvider)
        .request(
          chain: chain,
          rpcUrl: rpcNode.endpointUrl,
          method: request.method,
          params: request.params,
          headers: rpcNode.endpointHeaders,
        );
    final error = response.error;
    if (error != null) {
      return DappRequestResult.jsonRpcError(error);
    }
    return DappRequestResult.success(response.result);
  }

  Future<DappRequestResult> _personalSign(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionFor(request, context, now);
    if (permission == null) {
      if (authorizationDecision == DappAuthorizationDecision.rejected) {
        return const DappRequestResult.rejected();
      }
      if (_isApprovedAuthorization(authorizationDecision)) {
        permission = await _requestRef
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: request.domain,
              walletId: context.account.id,
              chainId: context.chain.chainId,
              address: context.account.evmAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.evmAddress,
          ),
        );
      }
    }

    final requestedAddress = _evmAddressFromParams(request.params);
    if (requestedAddress == null ||
        requestedAddress.toLowerCase() != permission.address.toLowerCase()) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    final message = _personalSignMessage(
      request.params,
      requestedAddress: requestedAddress,
    );
    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.signature,
          domain: request.domain,
          chain: context.chain,
          address: permission.address,
          message: _readableMessage(message),
          rawMessage: message,
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
    if (keyMaterial == null) {
      return const DappRequestResult.walletLocked();
    }

    final privateKey = keyMaterial.evmPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final signature = await _requestRef
        .read(dappEvmMessageSignerProvider)
        .signPersonalMessage(
          privateKey: privateKey,
          message: _messageBytes(message),
        );
    await _recordSignature(
      SecurityLogEventType.signMessage,
      account: context.account,
      chain: context.chain,
    );
    await _touch(request, context, now);
    return DappRequestResult.success(signature);
  }

  Future<DappRequestResult> _signTypedDataV4(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionFor(request, context, now);
    if (permission == null) {
      if (authorizationDecision == DappAuthorizationDecision.rejected) {
        return const DappRequestResult.rejected();
      }
      if (_isApprovedAuthorization(authorizationDecision)) {
        permission = await _requestRef
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: request.domain,
              walletId: context.account.id,
              chainId: context.chain.chainId,
              address: context.account.evmAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.evmAddress,
          ),
        );
      }
    }

    final typedData = _typedDataFromParams(request.params);
    final requestedAddress = _typedDataAddress(request.params);
    if (typedData == null ||
        requestedAddress == null ||
        requestedAddress.toLowerCase() != permission.address.toLowerCase()) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    if (!_typedDataMatchesEvmChain(typedData, context.chain)) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }
    final displayMessage = typedData.displayJson();
    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.signature,
          domain: request.domain,
          chain: context.chain,
          address: permission.address,
          message: displayMessage,
          rawMessage: displayMessage,
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
    if (keyMaterial == null) {
      return const DappRequestResult.walletLocked();
    }
    final privateKey = keyMaterial.evmPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }

    final signature = await _requestRef
        .read(dappEvmMessageSignerProvider)
        .signTypedData(
          privateKey: privateKey,
          payload: typedData.signingPayload(),
        );
    await _recordSignature(
      SecurityLogEventType.signMessage,
      account: context.account,
      chain: context.chain,
    );
    await _touch(request, context, now);
    return DappRequestResult.success(signature);
  }

  Future<DappRequestResult> _sendTransaction(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    bool signOnly = false,
    required DateTime now,
  }) async {
    final context = await _evmContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionFor(request, context, now);
    if (permission == null) {
      if (authorizationDecision == DappAuthorizationDecision.rejected) {
        return const DappRequestResult.rejected();
      }
      if (_isApprovedAuthorization(authorizationDecision)) {
        permission = await _requestRef
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: request.domain,
              walletId: context.account.id,
              chainId: context.chain.chainId,
              address: context.account.evmAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.evmAddress,
          ),
        );
      }
    }

    final transaction = _transactionFromParams(
      request.params,
      fallbackFrom: context.account.evmAddress,
    );
    if (transaction == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    if (!_sameEvmAddress(transaction.from, permission.address)) {
      return const DappRequestResult.failure('dapp_unauthorized');
    }

    final rpcNode = await _requestRef.read(
      selectedResolvedRpcNodeProvider(context.chain).future,
    );
    final simulation = await _requestRef
        .read(dappEvmTransactionSimulatorProvider)
        .simulate(
          chain: context.chain,
          rpcUrl: rpcNode.endpointUrl,
          transaction: transaction,
          headers: rpcNode.endpointHeaders,
        );
    final transactionTarget = transaction.to;
    final token = transactionTarget == null
        ? null
        : await _requestRef.read(dappEvmTokenLookupProvider)(
            chainId: context.chain.chainId,
            contractAddress: transactionTarget,
          );

    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.transaction,
          domain: request.domain,
          chain: context.chain,
          address: permission.address,
          transaction: transaction.preview(
            chain: context.chain,
            token: token,
            simulation: simulation,
          ),
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
    if (keyMaterial == null) {
      return const DappRequestResult.walletLocked();
    }

    final privateKey = keyMaterial.evmPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final transactionResult = signOnly
        ? await _requestRef
              .read(dappEvmTransactionSignerProvider)
              .sign(
                chain: context.chain,
                rpcUrl: rpcNode.endpointUrl,
                privateKey: privateKey,
                transaction: transaction,
                headers: rpcNode.endpointHeaders,
              )
        : await _requestRef
              .read(dappEvmTransactionSenderProvider)
              .send(
                chain: context.chain,
                rpcUrl: rpcNode.endpointUrl,
                privateKey: privateKey,
                transaction: transaction,
                headers: rpcNode.endpointHeaders,
              );
    await _recordSignature(
      SecurityLogEventType.signTransaction,
      account: context.account,
      chain: context.chain,
    );
    await _touch(request, context, now);
    if (!signOnly) {
      await _recordBroadcastTransaction(
        idPrefix: 'dapp-evm',
        chain: context.chain,
        account: context.account,
        transactionHash: transactionResult,
        amount: _formatUnits(transaction.valueWei ?? BigInt.zero, 18),
        toAddress: transaction.to,
        memo: request.method,
        now: now,
      );
    }
    return DappRequestResult.success(transactionResult);
  }

  Future<DappRequestResult> _switchEthereumChain(
    DappRpcRequest request, {
    required DappConfirmationDecision? confirmationDecision,
  }) async {
    final targetChainId = _requestedChainId(request.params);
    if (targetChainId == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final targetChain = await _chainForRpcChainId(targetChainId);
    if (targetChain == null) {
      return const DappRequestResult.failure('unsupported_chain');
    }
    final context = await _evmContext(request);
    final address = context?.account.evmAddress ?? '';
    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.chainSwitch,
          domain: request.domain,
          chain: context?.chain ?? targetChain,
          address: address,
          requestedChain: targetChain,
        ),
      );
    }
    if (confirmationDecision == DappConfirmationDecision.rejected) {
      return const DappRequestResult.rejected();
    }
    await _requestRef
        .read(selectedChainControllerProvider.notifier)
        .selectChain(targetChain.id);
    return const DappRequestResult.success(null);
  }

  Future<_DappEvmContext?> _evmContext(DappRpcRequest request) async {
    final chain = await _evmChain(request);
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
          _sameEvmAddress(wallet.evmAddress, address),
    );
    if (account == null || account.evmAddress.trim().isEmpty) {
      return null;
    }

    return _DappEvmContext(account: account, chain: chain);
  }

  Future<ChainConfig?> _evmChain(DappRpcRequest request) async {
    final requestChainId = request.chainId;
    if (requestChainId != null) {
      final reference = _caipReference(requestChainId, 'eip155');
      if (reference == null) {
        return null;
      }
      final chains = await _requestRef.read(availableChainsProvider.future);
      return _firstWhereOrNull<ChainConfig>(
        chains,
        (chain) =>
            chain.chainType == ChainType.evm && chain.chainId == reference,
      );
    }
    final selectedChain = await _requestRef.read(
      selectedChainControllerProvider.future,
    );
    if (selectedChain.chainType == ChainType.evm) {
      return selectedChain;
    }

    final chains = await _requestRef.read(availableChainsProvider.future);
    return _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.evm && chain.id == 'ethereum',
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.evm && !chain.isTestnet,
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.evm,
        );
  }

  Future<DappPermission?> _permissionFor(
    DappRpcRequest request,
    _DappEvmContext context,
    DateTime now,
  ) {
    if (request.source == DappRequestSource.walletConnect) {
      final address = request.authorizedAddress;
      if (address == null ||
          !_sameEvmAddress(address, context.account.evmAddress)) {
        return Future.value(null);
      }
      return Future.value(
        _walletConnectPermission(
          request,
          context.account,
          context.chain,
          address,
        ),
      );
    }
    return _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .permissionFor(
          domain: request.domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          now: now,
        );
  }

  Future<void> _touch(
    DappRpcRequest request,
    _DappEvmContext context,
    DateTime now,
  ) async {
    if (request.source == DappRequestSource.walletConnect) {
      return;
    }
    await _requestRef
        .read(dappPermissionControllerProvider.notifier)
        .touch(
          domain: request.domain,
          walletId: context.account.id,
          chainId: context.chain.chainId,
          now: now,
        );
  }

  Future<ChainConfig?> _chainForRpcChainId(String requestedChainId) async {
    final decimalChainId = _rpcChainIdToDecimal(requestedChainId);
    final chains = await _requestRef.read(availableChainsProvider.future);
    return _firstWhereOrNull(
      chains,
      (chain) =>
          chain.chainType == ChainType.evm && chain.chainId == decimalChainId,
    );
  }
}

final class _DappEvmContext {
  const _DappEvmContext({required this.account, required this.chain});

  final WalletAccount account;
  final ChainConfig chain;
}

bool _typedDataMatchesEvmChain(Eip712TypedData typedData, ChainConfig chain) {
  final rawChainId = typedData.domain['chainId'];
  if (rawChainId == null) {
    return true;
  }
  final typedDataChainId = _parseEip712ChainId(rawChainId);
  final requestChainId = BigInt.tryParse(chain.chainId);
  return typedDataChainId != null &&
      requestChainId != null &&
      typedDataChainId == requestChainId;
}

BigInt? _parseEip712ChainId(Object value) {
  if (value is int) {
    return value >= 0 ? BigInt.from(value) : null;
  }
  if (value is BigInt) {
    return value >= BigInt.zero ? value : null;
  }
  if (value is! String) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized.startsWith('0x')) {
    return BigInt.tryParse(normalized.substring(2), radix: 16);
  }
  return BigInt.tryParse(normalized);
}
