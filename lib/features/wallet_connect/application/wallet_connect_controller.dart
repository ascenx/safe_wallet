import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'wallet_connect_project_id_setting.dart'
    show walletConnectProjectIdProvider;

import '../data/wallet_connect_gateway.dart';
import '../data/wallet_connect_response_outbox.dart';
import '../domain/wallet_connect_models.dart';
import '../domain/wallet_connect_namespace.dart';
import '../../wallet/domain/wallet_account.dart';
import 'wallet_connect_project_id_setting.dart';
import 'wallet_connect_request_queue.dart';

enum WalletConnectStatus {
  uninitialized,
  initializing,
  ready,
  missingConfiguration,
  failure,
}

enum WalletConnectPairResult {
  accepted,
  invalidUri,
  duplicate,
  unavailable,
  failure,
}

final class WalletConnectState {
  const WalletConnectState({
    this.status = WalletConnectStatus.uninitialized,
    this.sessions = const [],
    this.pendingProposal,
    this.errorCode,
  });

  final WalletConnectStatus status;
  final List<WalletConnectSession> sessions;
  final WalletConnectProposal? pendingProposal;
  final String? errorCode;

  WalletConnectState copyWith({
    WalletConnectStatus? status,
    List<WalletConnectSession>? sessions,
    WalletConnectProposal? pendingProposal,
    bool clearPendingProposal = false,
    String? errorCode,
    bool clearError = false,
  }) {
    return WalletConnectState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      pendingProposal: clearPendingProposal
          ? null
          : pendingProposal ?? this.pendingProposal,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}

final walletConnectControllerProvider =
    NotifierProvider<WalletConnectController, WalletConnectState>(
      WalletConnectController.new,
    );

final class WalletConnectController extends Notifier<WalletConnectState> {
  static const _errorOutboxLifetime = Duration(days: 7);
  final WalletConnectRequestQueue requestQueue = WalletConnectRequestQueue();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Set<String> _pairedUriFingerprints = {};
  Future<void>? _initializeFuture;

  WalletConnectGateway get _gateway => ref.read(walletConnectGatewayProvider);

  @override
  WalletConnectState build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(requestQueue.dispose());
    });
    return const WalletConnectState();
  }

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _initialize();
    _initializeFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    final projectId = ref.read(walletConnectProjectIdProvider).trim();
    if (projectId.isEmpty) {
      state = state.copyWith(
        status: WalletConnectStatus.missingConfiguration,
        errorCode: 'wallet_connect_project_id_missing',
      );
      return;
    }
    state = state.copyWith(
      status: WalletConnectStatus.initializing,
      clearError: true,
    );
    try {
      await _gateway.initialize(
        WalletConnectConfiguration(
          projectId: projectId,
          metadata: const WalletConnectPeerMetadata(
            name: 'SafeWallet',
            description: 'A secure self-custody wallet',
            url: 'https://safewallet.app',
            icons: ['https://safewallet.app/icon.png'],
            nativeRedirect: 'safewallet://walletconnect',
          ),
        ),
      );
      _subscribe();
      await _refreshSessions();
      await _flushErrorOutbox();
      await _restorePendingWork();
      state = state.copyWith(
        status: WalletConnectStatus.ready,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        status: WalletConnectStatus.failure,
        errorCode: 'wallet_connect_initialize_failed',
      );
    }
  }

  void _subscribe() {
    if (_subscriptions.isNotEmpty) {
      return;
    }
    _subscriptions.addAll([
      _gateway.proposals.listen((proposal) {
        if (!proposal.isExpiredAt(DateTime.now())) {
          state = state.copyWith(pendingProposal: proposal);
        }
      }),
      _gateway.proposalExpired.listen((id) {
        if (state.pendingProposal?.id == id) {
          state = state.copyWith(clearPendingProposal: true);
        }
      }),
      _gateway.proposalsChanged.listen((_) {
        unawaited(_refreshPendingProposal());
      }),
      _gateway.requests.listen((request) {
        unawaited(_enqueueRequest(request));
      }),
      _gateway.sessionsChanged.listen((_) => unawaited(_refreshSessions())),
      _gateway.sessionDeleted.listen((topic) {
        requestQueue.cancelTopic(topic);
        unawaited(
          ref.read(walletConnectResponseOutboxProvider).removeTopic(topic),
        );
        unawaited(_refreshSessions());
      }),
    ]);
  }

  Future<WalletConnectPairResult> pair(String value) async {
    if (state.status != WalletConnectStatus.ready) {
      return WalletConnectPairResult.unavailable;
    }
    final input = value.trim();
    if (!_isValidPairingUri(input)) {
      return WalletConnectPairResult.invalidUri;
    }
    final fingerprint = await walletConnectPairingUriFingerprint(input);
    if (!_pairedUriFingerprints.add(fingerprint)) {
      return WalletConnectPairResult.duplicate;
    }
    try {
      await _gateway.pair(Uri.parse(input));
      return WalletConnectPairResult.accepted;
    } catch (_) {
      _pairedUriFingerprints.remove(fingerprint);
      return WalletConnectPairResult.failure;
    }
  }

  Future<void> approveProposal(
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) async {
    final proposal = state.pendingProposal;
    if (proposal == null || proposal.isExpiredAt(DateTime.now())) {
      return;
    }
    await approveProposalById(proposal.id, namespaces);
  }

  Future<void> approveProposalById(
    int proposalId,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) async {
    await _gateway.approveProposal(proposalId, namespaces);
    if (state.pendingProposal?.id == proposalId) {
      state = state.copyWith(clearPendingProposal: true);
    }
    await _refreshSessions();
    await _refreshPendingProposal();
  }

  Future<void> rejectProposal() async {
    final proposal = state.pendingProposal;
    if (proposal == null) {
      return;
    }
    await rejectProposalById(proposal.id);
  }

  Future<void> rejectProposalById(int proposalId) async {
    await _gateway.rejectProposal(proposalId);
    if (state.pendingProposal?.id == proposalId) {
      state = state.copyWith(clearPendingProposal: true);
    }
    await _refreshPendingProposal();
  }

  Future<void> disconnect(String topic) async {
    await _gateway.disconnect(topic);
    requestQueue.cancelTopic(topic);
    await ref.read(walletConnectResponseOutboxProvider).removeTopic(topic);
    await _refreshSessions();
  }

  Future<void> disconnectAll() async {
    final topics = state.sessions.map((session) => session.topic).toList();
    for (final topic in topics) {
      await disconnect(topic);
    }
  }

  Future<bool> disconnectWallet(WalletAccount account) async {
    if (state.status == WalletConnectStatus.uninitialized ||
        state.status == WalletConnectStatus.initializing) {
      await initialize();
    }
    if (state.status == WalletConnectStatus.missingConfiguration) {
      return true;
    }
    if (state.status != WalletConnectStatus.ready) {
      return false;
    }
    final addresses = <String>{
      account.evmAddress.toLowerCase(),
      account.solanaAddress,
    }..removeWhere((address) => address.isEmpty);
    final topics = state.sessions
        .where(
          (session) => session.namespaces.values.any(
            (namespace) => namespace.accounts.any(
              (sessionAccount) => addresses.contains(
                sessionAccount.chain.namespace == 'eip155'
                    ? sessionAccount.address.toLowerCase()
                    : sessionAccount.address,
              ),
            ),
          ),
        )
        .map((session) => session.topic)
        .toList(growable: false);
    for (final topic in topics) {
      await disconnect(topic);
    }
    return true;
  }

  Future<bool> reconfigure() async {
    final existingInitialization = _initializeFuture;
    if (existingInitialization != null) {
      await existingInitialization;
    }
    state = state.copyWith(
      status: WalletConnectStatus.initializing,
      sessions: const [],
      clearPendingProposal: true,
      clearError: true,
    );
    try {
      requestQueue.cancelAll();
      await _gateway.reset();
      await ref.read(walletConnectResponseOutboxProvider).clear();
      _pairedUriFingerprints.clear();
      _initializeFuture = null;
      await initialize();
      return state.status == WalletConnectStatus.ready ||
          state.status == WalletConnectStatus.missingConfiguration;
    } catch (_) {
      state = state.copyWith(
        status: WalletConnectStatus.failure,
        sessions: const [],
        clearPendingProposal: true,
        errorCode: 'wallet_connect_initialize_failed',
      );
      return false;
    }
  }

  Future<void> refresh() => _refreshSessions();

  Future<void> _refreshSessions() async {
    final sessions = await _gateway.getActiveSessions();
    final now = DateTime.now();
    state = state.copyWith(
      sessions: List.unmodifiable(
        sessions.where((session) => !session.isExpiredAt(now)),
      ),
    );
  }

  Future<void> _restorePendingWork() async {
    await _refreshPendingProposal();
    for (final request in await _gateway.getPendingRequests()) {
      await _enqueueRequest(request);
    }
  }

  Future<void> _enqueueRequest(WalletConnectRequest request) async {
    final result = requestQueue.enqueue(request);
    final response = switch (result) {
      WalletConnectEnqueueResult.expired => WalletConnectResponse.error(
        id: request.id,
        error: const WalletConnectResponseError(
          code: 8000,
          message: 'Request expired',
        ),
      ),
      WalletConnectEnqueueResult.full => WalletConnectResponse.error(
        id: request.id,
        error: const WalletConnectResponseError(
          code: -32000,
          message: 'Request queue is full',
        ),
      ),
      WalletConnectEnqueueResult.accepted ||
      WalletConnectEnqueueResult.duplicate => null,
    };
    if (response != null) {
      await respondError(request.topic, response);
    }
  }

  Future<void> respondError(
    String topic,
    WalletConnectResponse response,
  ) async {
    if (response.error == null) {
      throw ArgumentError('Only WalletConnect error responses may be queued');
    }
    final outbox = ref.read(walletConnectResponseOutboxProvider);
    var persisted = false;
    try {
      await outbox.put(
        WalletConnectErrorResponse(
          topic: topic,
          response: response,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      persisted = true;
    } catch (_) {
      // A storage failure still permits a best-effort direct response.
    }
    try {
      await _gateway.respond(topic, response);
      if (persisted) {
        await outbox.remove(topic: topic, id: response.id);
      }
    } catch (_) {
      // Persisted errors are retried on the next initialization.
    }
  }

  Future<void> _flushErrorOutbox() async {
    final outbox = ref.read(walletConnectResponseOutboxProvider);
    final now = DateTime.now().toUtc();
    for (final entry in await outbox.list()) {
      if (now.difference(entry.createdAt) > _errorOutboxLifetime) {
        await outbox.remove(topic: entry.topic, id: entry.response.id);
        continue;
      }
      try {
        await _gateway.respond(entry.topic, entry.response);
        await outbox.remove(topic: entry.topic, id: entry.response.id);
      } catch (_) {
        // Keep the entry for a later transport initialization.
      }
    }
  }

  Future<void> _refreshPendingProposal() async {
    final now = DateTime.now();
    final proposals =
        (await _gateway.getPendingProposals())
            .where((proposal) => !proposal.isExpiredAt(now))
            .toList()
          ..sort((left, right) => left.expiry.compareTo(right.expiry));
    if (proposals.isNotEmpty) {
      state = state.copyWith(pendingProposal: proposals.first);
    } else {
      state = state.copyWith(clearPendingProposal: true);
    }
  }
}

Future<String> walletConnectPairingUriFingerprint(String value) async {
  final digest = await Sha256().hash(utf8.encode(value));
  return base64UrlEncode(digest.bytes).replaceFirst(RegExp(r'=+$'), '');
}

bool _isValidPairingUri(String value) {
  if (value.isEmpty || value.length > 8192 || value.contains(RegExp(r'\s'))) {
    return false;
  }
  return RegExp(r'^wc:[^@]{1,256}@2\?.+$').hasMatch(value);
}
