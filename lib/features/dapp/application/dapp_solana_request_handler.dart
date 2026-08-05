part of 'dapp_request_controller.dart';

extension _DappSolanaRequestHandler on DappRequestController {
  Future<DappRequestResult> _connectSolana(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DateTime now,
  }) async {
    final context = await _solanaContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }

    final existing = await _permissionForSolana(request, context, now);
    if (existing != null) {
      await _touchSolana(request, context, now);
      return DappRequestResult.success({'publicKey': existing.address});
    }

    if (authorizationDecision == null) {
      return DappRequestResult.authorizationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.authorization,
          domain: request.domain,
          chain: context.chain,
          address: context.account.solanaAddress,
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
          address: context.account.solanaAddress,
          now: now,
          persistent: _isPersistentAuthorization(authorizationDecision),
        );
    return DappRequestResult.success({'publicKey': permission.address});
  }

  Future<DappRequestResult> _signSolanaMessage(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _solanaContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionForSolana(request, context, now);
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
              address: context.account.solanaAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.solanaAddress,
          ),
        );
      }
    }

    final message = _solanaMessageBytes(request.params);
    if (message == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }

    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.signature,
          domain: request.domain,
          chain: context.chain,
          address: permission.address,
          message: _readableBytes(message),
          rawMessage: _bytesToHex(message, include0x: true),
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

    final privateKey = keyMaterial.solanaPrivateKey;
    if (privateKey == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final signature = await _requestRef
        .read(dappSolanaMessageSignerProvider)
        .sign(privateKey: privateKey, message: message);
    await _recordSignature(
      SecurityLogEventType.signMessage,
      account: context.account,
      chain: context.chain,
    );
    await _touchSolana(request, context, now);
    return DappRequestResult.success({
      'signature': signature,
      'publicKey': permission.address,
    });
  }

  Future<DappRequestResult> _signSolanaTransaction(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _solanaContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionForSolana(request, context, now);
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
              address: context.account.solanaAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.solanaAddress,
          ),
        );
      }
    }

    final serializedTransaction = _solanaTransactionBytes(request.params);
    if (serializedTransaction == null) {
      return const DappRequestResult.failure('dapp_request_failed');
    }

    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.transaction,
          domain: request.domain,
          chain: context.chain,
          address: permission.address,
          transaction: _requestRef
              .read(dappTransactionPreviewerProvider)
              .previewSolana(
                from: permission.address,
                serializedTransaction: serializedTransaction,
              ),
        ),
      );
    }

    if (confirmationDecision == DappConfirmationDecision.rejected) {
      return const DappRequestResult.rejected();
    }

    final privateKey = await _readSolanaPrivateKey(
      context.account.id,
      now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    if (privateKey == null) {
      return const DappRequestResult.walletLocked();
    }

    final signedTransaction = await _requestRef
        .read(dappSolanaTransactionSignerProvider)
        .sign(
          privateKey: privateKey,
          serializedTransaction: serializedTransaction,
        );
    await _recordSignature(
      SecurityLogEventType.signTransaction,
      account: context.account,
      chain: context.chain,
    );
    await _touchSolana(request, context, now);
    return DappRequestResult.success({
      'serializedTransaction': signedTransaction,
    });
  }

  Future<DappRequestResult> _signAllSolanaTransactions(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final context = await _solanaContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    var permission = await _permissionForSolana(request, context, now);
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
              address: context.account.solanaAddress,
              now: now,
              persistent: _isPersistentAuthorization(authorizationDecision),
            );
      } else {
        return DappRequestResult.authorizationRequired(
          DappRequestConfirmation(
            kind: DappConfirmationKind.authorization,
            domain: request.domain,
            chain: context.chain,
            address: context.account.solanaAddress,
          ),
        );
      }
    }

    final transactions = _solanaTransactionsBytes(request.params);
    if (transactions == null || transactions.isEmpty) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final permissionAddress = permission.address;

    if (confirmationDecision == null) {
      return DappRequestResult.confirmationRequired(
        DappRequestConfirmation(
          kind: DappConfirmationKind.transaction,
          domain: request.domain,
          chain: context.chain,
          address: permissionAddress,
          transactions: transactions
              .map(
                (transaction) => _requestRef
                    .read(dappTransactionPreviewerProvider)
                    .previewSolana(
                      from: permissionAddress,
                      serializedTransaction: transaction,
                    ),
              )
              .toList(growable: false),
        ),
      );
    }

    if (confirmationDecision == DappConfirmationDecision.rejected) {
      return const DappRequestResult.rejected();
    }

    final privateKey = await _readSolanaPrivateKey(
      context.account.id,
      now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    if (privateKey == null) {
      return const DappRequestResult.walletLocked();
    }

    final signedTransactions = <List<int>>[];
    for (final transaction in transactions) {
      signedTransactions.add(
        await _requestRef
            .read(dappSolanaTransactionSignerProvider)
            .sign(privateKey: privateKey, serializedTransaction: transaction),
      );
    }
    await _recordSignature(
      SecurityLogEventType.signTransaction,
      account: context.account,
      chain: context.chain,
    );
    await _touchSolana(request, context, now);
    return DappRequestResult.success({
      'serializedTransactions': signedTransactions,
    });
  }

  Future<DappRequestResult> _signAndSendSolanaTransaction(
    DappRpcRequest request, {
    required DappAuthorizationDecision? authorizationDecision,
    required DappConfirmationDecision? confirmationDecision,
    required String? signingPassword,
    required bool rememberSigningPassword,
    required DateTime now,
  }) async {
    final signResult = await _signSolanaTransaction(
      request,
      authorizationDecision: authorizationDecision,
      confirmationDecision: confirmationDecision,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
      now: now,
    );
    if (!signResult.isSuccess) {
      return signResult;
    }
    final value = signResult.value;
    if (value is! Map || value['serializedTransaction'] is! List) {
      return const DappRequestResult.failure('dapp_request_failed');
    }
    final context = await _solanaContext(request);
    if (context == null) {
      return const DappRequestResult.walletLocked();
    }
    final serializedTransaction = (value['serializedTransaction'] as List)
        .cast<int>();
    final rpcNode = await _requestRef.read(
      selectedResolvedRpcNodeProvider(context.chain).future,
    );
    final signature = await _requestRef
        .read(dappSolanaRawTransactionSenderProvider)
        .send(
          chain: context.chain,
          rpcUrl: rpcNode.endpointUrl,
          serializedTransaction: serializedTransaction,
          headers: rpcNode.endpointHeaders,
        );
    await _recordBroadcastTransaction(
      idPrefix: 'dapp-solana',
      chain: context.chain,
      account: context.account,
      transactionHash: signature,
      amount: '0',
      memo: request.method,
      now: now,
    );
    return DappRequestResult.success({
      'signature': signature,
      'publicKey': context.account.solanaAddress,
    });
  }

  Future<_DappSolanaContext?> _solanaContext(DappRpcRequest request) async {
    final chain = await _solanaChain(request);
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
          wallet.solanaAddress == address,
    );
    if (account == null || account.solanaAddress.isEmpty) {
      return null;
    }

    return _DappSolanaContext(account: account, chain: chain);
  }

  Future<ChainConfig?> _solanaChain(DappRpcRequest request) async {
    final requestChainId = request.chainId;
    if (requestChainId != null) {
      final reference = _caipReference(requestChainId, 'solana');
      if (reference == null) {
        return null;
      }
      final internalChainId = switch (reference) {
        '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp' => 'mainnet-beta',
        'EtWTRABZaYq6iMfeYKouRu166VU2xqa1' => 'devnet',
        '4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z' => 'testnet',
        _ => null,
      };
      if (internalChainId == null) {
        return null;
      }
      final chains = await _requestRef.read(availableChainsProvider.future);
      return _firstWhereOrNull<ChainConfig>(
        chains,
        (chain) =>
            chain.chainType == ChainType.solana &&
            chain.chainId == internalChainId,
      );
    }
    final selectedChain = await _requestRef.read(
      selectedChainControllerProvider.future,
    );
    if (selectedChain.chainType == ChainType.solana) {
      return selectedChain;
    }

    final chains = await _requestRef.read(availableChainsProvider.future);
    return _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) =>
              chain.chainType == ChainType.solana &&
              chain.id == 'solana-mainnet',
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.solana && !chain.isTestnet,
        ) ??
        _firstWhereOrNull<ChainConfig>(
          chains,
          (chain) => chain.chainType == ChainType.solana,
        );
  }

  Future<DappPermission?> _permissionForSolana(
    DappRpcRequest request,
    _DappSolanaContext context,
    DateTime now,
  ) {
    if (request.source == DappRequestSource.walletConnect) {
      final address = request.authorizedAddress;
      if (address == null || address != context.account.solanaAddress) {
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

  Future<void> _touchSolana(
    DappRpcRequest request,
    _DappSolanaContext context,
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

  Future<List<int>?> _readSolanaPrivateKey(
    String walletId,
    DateTime now, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final keyMaterial = await _readSigningKeyMaterial(
      walletId,
      now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    return keyMaterial?.solanaPrivateKey;
  }
}

final class _DappSolanaContext {
  const _DappSolanaContext({required this.account, required this.chain});

  final WalletAccount account;
  final ChainConfig chain;
}
