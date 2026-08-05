part of 'wallet_connect_gateway.dart';

typedef ReownWalletKitTransportFactory =
    Future<ReownWalletKitTransport> Function(
      WalletConnectConfiguration configuration,
    );

abstract interface class ReownWalletKitTransport {
  Stream<reown.SessionProposalEvent> get proposals;
  Stream<int> get proposalExpired;
  Stream<void> get proposalsChanged;
  Stream<reown.SessionRequestEvent> get requests;
  Stream<void> get sessionsChanged;
  Stream<String> get sessionDeleted;

  Map<String, reown.SessionData> getActiveSessions();
  Map<String, reown.ProposalData> getPendingSessionProposals();
  Map<String, reown.SessionRequest> getPendingSessionRequests();
  Future<void> pair(Uri uri);
  Future<void> approveSession(int id, Map<String, reown.Namespace> namespaces);
  Future<void> rejectSession(int id, reown.ReownSignError reason);
  Future<void> respondSessionRequest(
    String topic,
    reown.JsonRpcResponse response,
  );
  Future<void> disconnectSession(String topic, reown.ReownSignError reason);
  Future<void> clearPairings();
  Future<void> dispose();
}

final class ReownWalletConnectGateway implements WalletConnectGateway {
  ReownWalletConnectGateway({
    ReownWalletKitTransportFactory? transportFactory,
    DateTime Function()? now,
  }) : _transportFactory = transportFactory ?? _createReownTransport,
       _now = now ?? DateTime.now;

  static const Duration _localRequestLifetime = Duration(minutes: 5);

  final ReownWalletKitTransportFactory _transportFactory;
  final DateTime Function() _now;
  final StreamController<WalletConnectProposal> _proposalController =
      StreamController.broadcast(sync: true);
  final StreamController<int> _proposalExpiredController =
      StreamController.broadcast(sync: true);
  final StreamController<void> _proposalsChangedController =
      StreamController.broadcast(sync: true);
  final StreamController<WalletConnectRequest> _requestController =
      StreamController.broadcast(sync: true);
  final StreamController<void> _sessionsChangedController =
      StreamController.broadcast(sync: true);
  final StreamController<String> _sessionDeletedController =
      StreamController.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Map<String, DateTime> _sessionFirstSeen = {};

  ReownWalletKitTransport? _transport;
  bool _disposed = false;

  ReownWalletKitTransport get _client {
    final transport = _transport;
    if (transport == null) {
      throw StateError('wallet_connect_transport_not_initialized');
    }
    return transport;
  }

  @override
  Stream<WalletConnectProposal> get proposals => _proposalController.stream;

  @override
  Stream<int> get proposalExpired => _proposalExpiredController.stream;

  @override
  Stream<void> get proposalsChanged => _proposalsChangedController.stream;

  @override
  Stream<WalletConnectRequest> get requests => _requestController.stream;

  @override
  Stream<void> get sessionsChanged => _sessionsChangedController.stream;

  @override
  Stream<String> get sessionDeleted => _sessionDeletedController.stream;

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {
    if (_disposed) {
      throw StateError('wallet_connect_transport_disposed');
    }
    if (_transport != null) {
      return;
    }
    final transport = await _transportFactory(configuration);
    if (_disposed) {
      await transport.dispose();
      return;
    }
    _transport = transport;
    _subscriptions.addAll([
      transport.proposals.listen((event) {
        final proposal = _tryMapProposal(
          event.params,
          verifyContext: event.verifyContext,
        );
        if (proposal != null) {
          _proposalController.add(proposal);
        }
      }),
      transport.proposalExpired.listen(_proposalExpiredController.add),
      transport.proposalsChanged.listen(_proposalsChangedController.add),
      transport.requests.listen((event) {
        final pending = _pendingRequest(event.topic, event.id);
        final request = _tryMapRequest(
          id: event.id,
          topic: event.topic,
          chainId: event.chainId,
          method: event.method,
          params: event.params,
          verifyContext: pending?.verifyContext,
        );
        if (request != null) {
          _requestController.add(request);
        }
      }),
      transport.sessionsChanged.listen(_sessionsChangedController.add),
      transport.sessionDeleted.listen((topic) {
        _sessionFirstSeen.remove(topic);
        _sessionDeletedController.add(topic);
      }),
    ]);
  }

  @override
  Future<void> pair(Uri uri) => _client.pair(uri);

  @override
  Future<List<WalletConnectSession>> getActiveSessions() async {
    final sessions = <WalletConnectSession>[];
    for (final session in _client.getActiveSessions().values) {
      final mapped = _tryMapSession(session);
      if (mapped != null) {
        sessions.add(mapped);
      }
    }
    sessions.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List.unmodifiable(sessions);
  }

  @override
  Future<List<WalletConnectProposal>> getPendingProposals() async {
    final proposals =
        _client
            .getPendingSessionProposals()
            .values
            .map(_tryMapProposal)
            .whereType<WalletConnectProposal>()
            .toList()
          ..sort((left, right) => left.expiry.compareTo(right.expiry));
    return List.unmodifiable(proposals);
  }

  @override
  Future<List<WalletConnectRequest>> getPendingRequests() async {
    final requests = <WalletConnectRequest>[];
    for (final request in _client.getPendingSessionRequests().values) {
      final mapped = _tryMapRequest(
        id: request.id,
        topic: request.topic,
        chainId: request.chainId,
        method: request.method,
        params: request.params,
        verifyContext: request.verifyContext,
      );
      if (mapped != null) {
        requests.add(mapped);
      }
    }
    requests.sort((left, right) => left.id.compareTo(right.id));
    return List.unmodifiable(requests);
  }

  @override
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) {
    final sdkNamespaces = namespaces.map(
      (key, value) => MapEntry(
        key,
        reown.Namespace(
          chains: _sorted(value.chains.map((chain) => chain.toString())),
          accounts: _sorted(
            value.accounts.map((account) => account.toString()),
          ),
          methods: _sorted(value.methods),
          events: _sorted(value.events),
        ),
      ),
    );
    return _client.approveSession(id, sdkNamespaces);
  }

  @override
  Future<void> rejectProposal(int id) {
    return _client.rejectSession(id, _signError(reown.Errors.USER_REJECTED));
  }

  @override
  Future<void> respond(String topic, WalletConnectResponse response) {
    final error = response.error;
    return _client.respondSessionRequest(
      topic,
      reown.JsonRpcResponse(
        id: response.id,
        result: response.result,
        error: error == null
            ? null
            : reown.JsonRpcError(code: error.code, message: error.message),
      ),
    );
  }

  @override
  Future<void> disconnect(String topic) {
    return _client.disconnectSession(
      topic,
      _signError(reown.Errors.USER_DISCONNECTED),
    );
  }

  @override
  Future<void> reset() async {
    if (_disposed) {
      throw StateError('wallet_connect_transport_disposed');
    }
    await _releaseTransport(clearPairings: true);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _releaseTransport(clearPairings: false);
    await _proposalController.close();
    await _proposalExpiredController.close();
    await _proposalsChangedController.close();
    await _requestController.close();
    await _sessionsChangedController.close();
    await _sessionDeletedController.close();
  }

  Future<void> _releaseTransport({required bool clearPairings}) async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final transport = _transport;
    _transport = null;
    if (transport != null) {
      if (clearPairings) {
        await transport.clearPairings();
      }
      await transport.dispose();
    }
    _sessionFirstSeen.clear();
  }

  WalletConnectProposal? _tryMapProposal(
    reown.ProposalData proposal, {
    reown.VerifyContext? verifyContext,
  }) {
    try {
      return WalletConnectProposal(
        id: proposal.id,
        pairingTopic: proposal.pairingTopic,
        peer: _mapMetadata(proposal.proposer.metadata),
        requiredNamespaces: _mapProposedNamespaces(proposal.requiredNamespaces),
        optionalNamespaces: _mapProposedNamespaces(proposal.optionalNamespaces),
        expiry: _fromSeconds(proposal.expiry),
        verifyContext: _mapVerifyContext(verifyContext),
      );
    } on FormatException {
      return null;
    }
  }

  WalletConnectSession? _tryMapSession(reown.SessionData session) {
    try {
      return WalletConnectSession(
        topic: session.topic,
        pairingTopic: session.pairingTopic,
        peer: _mapMetadata(session.peer.metadata),
        namespaces: _mapApprovedNamespaces(session.namespaces),
        expiry: _fromSeconds(session.expiry),
        createdAt: _sessionFirstSeen.putIfAbsent(session.topic, _now),
      );
    } on FormatException {
      return null;
    }
  }

  WalletConnectRequest? _tryMapRequest({
    required int id,
    required String topic,
    required String chainId,
    required String method,
    required Object? params,
    reown.VerifyContext? verifyContext,
  }) {
    if (!_hasSafeRequestStructure(params)) {
      return null;
    }
    final session = _client.getActiveSessions()[topic];
    if (session == null) {
      return null;
    }
    try {
      return WalletConnectRequest(
        id: id,
        topic: topic,
        chain: Caip2ChainId.parse(chainId),
        method: method,
        params: params,
        peer: _mapMetadata(session.peer.metadata),
        expiry: _now().add(_localRequestLifetime),
        verifyContext: _mapVerifyContext(verifyContext),
      );
    } on FormatException {
      return null;
    }
  }

  reown.SessionRequest? _pendingRequest(String topic, int id) {
    for (final request in _client.getPendingSessionRequests().values) {
      if (request.topic == topic && request.id == id) {
        return request;
      }
    }
    return null;
  }
}

Future<ReownWalletKitTransport> _createReownTransport(
  WalletConnectConfiguration configuration,
) async {
  final metadata = configuration.metadata;
  final walletKit = await reown.ReownWalletKit.createInstance(
    projectId: configuration.projectId,
    metadata: reown.PairingMetadata(
      name: metadata.name,
      description: metadata.description,
      url: metadata.url,
      icons: metadata.icons,
      redirect: reown.Redirect(
        native: metadata.nativeRedirect,
        universal: metadata.universalRedirect,
      ),
    ),
    logLevel: reown.LogLevel.nothing,
  );
  return _ReownWalletKitTransport(walletKit);
}

final class _ReownWalletKitTransport implements ReownWalletKitTransport {
  _ReownWalletKitTransport(this._walletKit) {
    _walletKit.onSessionProposal.subscribe(_onProposal);
    _walletKit.onProposalExpire.subscribe(_onProposalExpired);
    _walletKit.core.pairing.onPairingDelete.subscribe(_onPairingChanged);
    _walletKit.core.pairing.onPairingExpire.subscribe(_onPairingChanged);
    _walletKit.onSessionRequest.subscribe(_onRequest);
    _walletKit.onSessionConnect.subscribe(_onSessionConnect);
    _walletKit.reOwnSign.onSessionUpdate.subscribe(_onSessionUpdate);
    _walletKit.reOwnSign.onSessionExtend.subscribe(_onSessionExtend);
    _walletKit.onSessionDelete.subscribe(_onSessionDelete);
  }

  final reown.ReownWalletKit _walletKit;
  final StreamController<reown.SessionProposalEvent> _proposalController =
      StreamController.broadcast(sync: true);
  final StreamController<int> _proposalExpiredController =
      StreamController.broadcast(sync: true);
  final StreamController<void> _proposalsChangedController =
      StreamController.broadcast(sync: true);
  final StreamController<reown.SessionRequestEvent> _requestController =
      StreamController.broadcast(sync: true);
  final StreamController<void> _sessionsChangedController =
      StreamController.broadcast(sync: true);
  final StreamController<String> _sessionDeletedController =
      StreamController.broadcast(sync: true);
  bool _disposed = false;

  @override
  Stream<reown.SessionProposalEvent> get proposals =>
      _proposalController.stream;

  @override
  Stream<int> get proposalExpired => _proposalExpiredController.stream;

  @override
  Stream<void> get proposalsChanged => _proposalsChangedController.stream;

  @override
  Stream<reown.SessionRequestEvent> get requests => _requestController.stream;

  @override
  Stream<void> get sessionsChanged => _sessionsChangedController.stream;

  @override
  Stream<String> get sessionDeleted => _sessionDeletedController.stream;

  @override
  Map<String, reown.SessionData> getActiveSessions() =>
      _walletKit.getActiveSessions();

  @override
  Map<String, reown.ProposalData> getPendingSessionProposals() =>
      _walletKit.getPendingSessionProposals();

  @override
  Map<String, reown.SessionRequest> getPendingSessionRequests() =>
      _walletKit.getPendingSessionRequests();

  @override
  Future<void> pair(Uri uri) async {
    await _walletKit.pair(uri: uri);
  }

  @override
  Future<void> approveSession(
    int id,
    Map<String, reown.Namespace> namespaces,
  ) async {
    await _walletKit.approveSession(id: id, namespaces: namespaces);
  }

  @override
  Future<void> rejectSession(int id, reown.ReownSignError reason) {
    return _walletKit.rejectSession(id: id, reason: reason);
  }

  @override
  Future<void> respondSessionRequest(
    String topic,
    reown.JsonRpcResponse response,
  ) {
    return _walletKit.respondSessionRequest(topic: topic, response: response);
  }

  @override
  Future<void> disconnectSession(String topic, reown.ReownSignError reason) {
    return _walletKit.disconnectSession(topic: topic, reason: reason);
  }

  void _onProposal(reown.SessionProposalEvent event) {
    _proposalController.add(event);
  }

  void _onProposalExpired(reown.SessionProposalEvent event) {
    _proposalExpiredController.add(event.id);
  }

  void _onPairingChanged(reown.PairingEvent event) {
    _proposalsChangedController.add(null);
  }

  void _onRequest(reown.SessionRequestEvent event) {
    _requestController.add(event);
  }

  void _onSessionConnect(reown.SessionConnect event) {
    _sessionsChangedController.add(null);
  }

  void _onSessionUpdate(reown.SessionUpdate event) {
    _sessionsChangedController.add(null);
  }

  void _onSessionExtend(reown.SessionExtend event) {
    _sessionsChangedController.add(null);
  }

  void _onSessionDelete(reown.SessionDelete event) {
    _sessionDeletedController.add(event.topic);
  }

  @override
  Future<void> clearPairings() async {
    final pairings = List.of(_walletKit.core.pairing.getPairings());
    for (final pairing in pairings) {
      try {
        await _walletKit.core.pairing.disconnect(topic: pairing.topic);
      } catch (_) {
        // Expired or already-deleted pairings do not block runtime reset.
      }
    }
    await _walletKit.core.storage.deleteAll();
    await _walletKit.core.secureStorage.deleteAll();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _walletKit.onSessionProposal.unsubscribe(_onProposal);
    _walletKit.onProposalExpire.unsubscribe(_onProposalExpired);
    _walletKit.core.pairing.onPairingDelete.unsubscribe(_onPairingChanged);
    _walletKit.core.pairing.onPairingExpire.unsubscribe(_onPairingChanged);
    _walletKit.onSessionRequest.unsubscribe(_onRequest);
    _walletKit.onSessionConnect.unsubscribe(_onSessionConnect);
    _walletKit.reOwnSign.onSessionUpdate.unsubscribe(_onSessionUpdate);
    _walletKit.reOwnSign.onSessionExtend.unsubscribe(_onSessionExtend);
    _walletKit.onSessionDelete.unsubscribe(_onSessionDelete);
    WidgetsBinding.instance.removeObserver(_walletKit);
    await _walletKit.core.relayClient.disconnect();
    await _proposalController.close();
    await _proposalExpiredController.close();
    await _proposalsChangedController.close();
    await _requestController.close();
    await _sessionsChangedController.close();
    await _sessionDeletedController.close();
  }
}

Map<String, WalletConnectNamespaceProposal> _mapProposedNamespaces(
  Map<String, reown.RequiredNamespace> source,
) {
  final builders = <String, _ProposedNamespaceBuilder>{};
  for (final entry in source.entries) {
    final keyChain = _chainFromNamespaceKey(entry.key);
    final namespace = keyChain?.namespace ?? entry.key;
    final builder = builders.putIfAbsent(
      namespace,
      _ProposedNamespaceBuilder.new,
    );
    if (keyChain != null) {
      builder.chains.add(keyChain);
    }
    for (final value in entry.value.chains ?? const <String>[]) {
      builder.chains.add(Caip2ChainId.parse(value));
    }
    builder.methods.addAll(entry.value.methods);
    builder.events.addAll(entry.value.events);
  }
  return Map.unmodifiable(
    builders.map(
      (key, value) => MapEntry(
        key,
        WalletConnectNamespaceProposal(
          chains: Set.unmodifiable(value.chains),
          methods: Set.unmodifiable(value.methods),
          events: Set.unmodifiable(value.events),
        ),
      ),
    ),
  );
}

Map<String, WalletConnectApprovedNamespace> _mapApprovedNamespaces(
  Map<String, reown.Namespace> source,
) {
  final builders = <String, _ApprovedNamespaceBuilder>{};
  for (final entry in source.entries) {
    final keyChain = _chainFromNamespaceKey(entry.key);
    final namespace = keyChain?.namespace ?? entry.key;
    final builder = builders.putIfAbsent(
      namespace,
      _ApprovedNamespaceBuilder.new,
    );
    if (keyChain != null) {
      builder.chains.add(keyChain);
    }
    for (final value in entry.value.chains ?? const <String>[]) {
      builder.chains.add(Caip2ChainId.parse(value));
    }
    for (final value in entry.value.accounts) {
      final account = Caip10AccountId.parse(value);
      builder.accounts.add(account);
      builder.chains.add(account.chain);
    }
    builder.methods.addAll(entry.value.methods);
    builder.events.addAll(entry.value.events);
  }
  return Map.unmodifiable(
    builders.map(
      (key, value) => MapEntry(
        key,
        WalletConnectApprovedNamespace(
          chains: Set.unmodifiable(value.chains),
          accounts: Set.unmodifiable(value.accounts),
          methods: Set.unmodifiable(value.methods),
          events: Set.unmodifiable(value.events),
        ),
      ),
    ),
  );
}

Caip2ChainId? _chainFromNamespaceKey(String value) {
  if (!value.contains(':')) {
    return null;
  }
  return Caip2ChainId.parse(value);
}

WalletConnectPeerMetadata _mapMetadata(reown.PairingMetadata metadata) {
  return WalletConnectPeerMetadata(
    name: _boundedText(metadata.name, 256),
    description: _boundedText(metadata.description, 2048),
    url: _boundedText(metadata.url, 2048),
    icons: List.unmodifiable(
      metadata.icons.take(8).map((value) => _boundedText(value, 2048)),
    ),
    nativeRedirect: _boundedOptionalText(metadata.redirect?.native, 2048),
    universalRedirect: _boundedOptionalText(metadata.redirect?.universal, 2048),
  );
}

WalletConnectVerifyContext? _mapVerifyContext(reown.VerifyContext? context) {
  if (context == null) {
    return null;
  }
  final origin = _safeVerifyUrl(context.origin);
  final status = context.isScam == true || context.validation.scam
      ? WalletConnectVerifyStatus.scam
      : origin.isEmpty
      ? WalletConnectVerifyStatus.unknown
      : switch (context.validation) {
          reown.Validation.VALID => WalletConnectVerifyStatus.valid,
          reown.Validation.INVALID => WalletConnectVerifyStatus.invalid,
          reown.Validation.SCAM => WalletConnectVerifyStatus.scam,
          reown.Validation.UNKNOWN => WalletConnectVerifyStatus.unknown,
        };
  final verifyUrl = _safeVerifyUrl(context.verifyUrl);
  return WalletConnectVerifyContext(
    origin: origin,
    status: status,
    verifyUrl: verifyUrl.isEmpty ? null : verifyUrl,
  );
}

String _safeVerifyUrl(String value) {
  final bounded = _boundedText(value.trim(), 2048);
  final uri = Uri.tryParse(bounded);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return '';
  }
  return uri.origin;
}

String _boundedText(String value, int maxRunes) {
  if (value.runes.length <= maxRunes) {
    return value;
  }
  return String.fromCharCodes(value.runes.take(maxRunes));
}

String? _boundedOptionalText(String? value, int maxRunes) {
  return value == null ? null : _boundedText(value, maxRunes);
}

DateTime _fromSeconds(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

reown.ReownSignError _signError(String key) {
  final error = reown.Errors.getSdkError(key);
  return reown.ReownSignError(code: error.code, message: error.message);
}

bool _hasSafeRequestStructure(Object? value) {
  var remainingNodes = 4096;

  bool visit(Object? current, int depth) {
    remainingNodes -= 1;
    if (remainingNodes < 0 || depth > 16) {
      return false;
    }
    if (current == null || current is num || current is bool) {
      return true;
    }
    if (current is String) {
      return current.length <= 131072;
    }
    if (current is List) {
      return current.length <= 256 &&
          current.every((item) => visit(item, depth + 1));
    }
    if (current is Map) {
      if (current.length > 256) {
        return false;
      }
      for (final entry in current.entries) {
        final key = entry.key;
        if (key is! String ||
            key.length > 256 ||
            !visit(entry.value, depth + 1)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  return visit(value, 0);
}

base class _ProposedNamespaceBuilder {
  final Set<Caip2ChainId> chains = {};
  final Set<String> methods = {};
  final Set<String> events = {};
}

final class _ApprovedNamespaceBuilder extends _ProposedNamespaceBuilder {
  final Set<Caip10AccountId> accounts = {};
}
