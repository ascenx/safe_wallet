import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reown_walletkit/reown_walletkit.dart' as reown;
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1, 12);

  test(
    'maps restored SDK proposals, sessions, and requests into domain models',
    () async {
      final transport = _FakeTransport(
        sessions: {'topic-a': _sdkSession},
        proposals: {'9': _sdkProposal},
        requests: {'topic-a:7': _sdkRequest},
      );
      final gateway = ReownWalletConnectGateway(
        transportFactory: (_) async => transport,
        now: () => now,
      );
      addTearDown(gateway.dispose);

      await gateway.initialize(_configuration);

      final proposals = await gateway.getPendingProposals();
      expect(proposals, hasLength(1));
      expect(proposals.single.peer.name, 'Example dApp');
      expect(proposals.single.requiredNamespaces.keys, ['eip155']);
      expect(proposals.single.requiredNamespaces['eip155']!.chains, {
        const Caip2ChainId(namespace: 'eip155', reference: '1'),
        const Caip2ChainId(namespace: 'eip155', reference: '56'),
      });
      expect(proposals.single.requiredNamespaces['eip155']!.methods, {
        'personal_sign',
        'eth_sendTransaction',
      });

      final sessions = await gateway.getActiveSessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.topic, 'topic-a');
      expect(
        sessions.single.namespaces['eip155']!.accounts.single.toString(),
        'eip155:1:0xabc',
      );

      final requests = await gateway.getPendingRequests();
      expect(requests, hasLength(1));
      expect(requests.single.peer.name, 'Example dApp');
      expect(requests.single.chain.toString(), 'eip155:1');
      expect(requests.single.expiry, now.add(const Duration(minutes: 5)));
      expect(
        requests.single.verifyContext?.status,
        WalletConnectVerifyStatus.valid,
      );
    },
  );

  test(
    'drops oversized request params before they enter the confirmation UI',
    () async {
      final oversizedRequest = reown.SessionRequest(
        id: 8,
        topic: 'topic-a',
        chainId: 'eip155:1',
        method: 'personal_sign',
        params: ['a' * 131073, '0xabc'],
        verifyContext: const reown.VerifyContext(
          origin: 'https://example.com',
          validation: reown.Validation.VALID,
          verifyUrl: 'https://verify.walletconnect.com',
        ),
      );
      final transport = _FakeTransport(
        sessions: {'topic-a': _sdkSession},
        requests: {'topic-a:8': oversizedRequest},
      );
      final gateway = ReownWalletConnectGateway(
        transportFactory: (_) async => transport,
        now: () => now,
      );
      addTearDown(gateway.dispose);
      await gateway.initialize(_configuration);

      expect(await gateway.getPendingRequests(), isEmpty);
    },
  );

  test(
    'bounds untrusted peer metadata before storing it in UI state',
    () async {
      final metadata = _peerMetadata.copyWith(
        name: 'n' * 300,
        description: 'd' * 3000,
        url: 'https://example.com/${'u' * 3000}',
        icons: List.filled(20, 'https://example.com/icon.png'),
      );
      final proposal = _sdkProposal.copyWith(
        proposer: reown.ConnectionMetadata(
          publicKey: 'peer-key',
          metadata: metadata,
        ),
      );
      final transport = _FakeTransport(proposals: {'9': proposal});
      final gateway = ReownWalletConnectGateway(
        transportFactory: (_) async => transport,
        now: () => now,
      );
      addTearDown(gateway.dispose);
      await gateway.initialize(_configuration);

      final peer = (await gateway.getPendingProposals()).single.peer;
      expect(peer.name.length, 256);
      expect(peer.description.length, 2048);
      expect(peer.url.length, 2048);
      expect(peer.icons, hasLength(8));
    },
  );

  test(
    'maps live SDK events without registering automatic request handlers',
    () async {
      final transport = _FakeTransport(sessions: {'topic-a': _sdkSession});
      final gateway = ReownWalletConnectGateway(
        transportFactory: (_) async => transport,
        now: () => now,
      );
      addTearDown(gateway.dispose);
      await gateway.initialize(_configuration);

      final proposalFuture = gateway.proposals.first;
      final requestFuture = gateway.requests.first;
      final expiryFuture = gateway.proposalExpired.first;
      final sessionChangedFuture = gateway.sessionsChanged.first;
      final deletedFuture = gateway.sessionDeleted.first;

      transport.proposalController.add(
        reown.SessionProposalEvent(
          9,
          _sdkProposal,
          const reown.VerifyContext(
            origin: 'https://phishing.example',
            validation: reown.Validation.SCAM,
            verifyUrl: 'https://verify.walletconnect.com',
            isScam: true,
          ),
        ),
      );
      transport.pendingRequests['7'] = _sdkRequest;
      transport.requestController.add(
        reown.SessionRequestEvent(
          7,
          'topic-a',
          'personal_sign',
          'eip155:1',
          const ['0x01', '0xabc'],
          reown.TransportType.relay,
        ),
      );
      transport.proposalExpiredController.add(9);
      transport.sessionsChangedController.add(null);
      transport.sessionDeletedController.add('topic-a');

      final proposal = await proposalFuture;
      expect(proposal.id, 9);
      expect(proposal.verifyContext?.status, WalletConnectVerifyStatus.scam);
      final request = await requestFuture;
      expect(request.id, 7);
      expect(request.verifyContext?.status, WalletConnectVerifyStatus.valid);
      expect(await expiryFuture, 9);
      await sessionChangedFuture;
      expect(await deletedFuture, 'topic-a');
      expect(transport.automaticHandlerRegistrations, 0);
    },
  );

  test(
    'forwards approvals, responses, rejection, and disconnect to the SDK',
    () async {
      final transport = _FakeTransport(sessions: {'topic-a': _sdkSession});
      final gateway = ReownWalletConnectGateway(
        transportFactory: (_) async => transport,
        now: () => now,
      );
      addTearDown(gateway.dispose);
      await gateway.initialize(_configuration);

      await gateway.approveProposal(9, {
        'eip155': WalletConnectApprovedNamespace(
          chains: {const Caip2ChainId(namespace: 'eip155', reference: '1')},
          accounts: {
            const Caip10AccountId(
              chain: Caip2ChainId(namespace: 'eip155', reference: '1'),
              address: '0xabc',
            ),
          },
          methods: const {'personal_sign'},
          events: const {'accountsChanged'},
        ),
      });
      await gateway.respond(
        'topic-a',
        const WalletConnectResponse.success(id: 7, result: '0xsigned'),
      );
      await gateway.respond(
        'topic-a',
        const WalletConnectResponse.error(
          id: 8,
          error: WalletConnectResponseError(code: 4001, message: 'Rejected'),
        ),
      );
      await gateway.rejectProposal(10);
      await gateway.disconnect('topic-a');

      final namespace = transport.approvedNamespaces.single['eip155']!;
      expect(namespace.chains, ['eip155:1']);
      expect(namespace.accounts, ['eip155:1:0xabc']);
      expect(namespace.methods, ['personal_sign']);
      expect(namespace.events, ['accountsChanged']);
      expect(transport.responses[0].response.result, '0xsigned');
      expect(transport.responses[1].response.error?.code, 4001);
      expect(transport.rejectionReasons.single.code, 5000);
      expect(transport.disconnectReasons.single.code, 6000);
    },
  );

  test(
    'reset clears pairings and allows initialization with a new Project ID',
    () async {
      final firstTransport = _FakeTransport();
      final secondTransport = _FakeTransport();
      final transports = [firstTransport, secondTransport];
      final initializedProjectIds = <String>[];
      final gateway = ReownWalletConnectGateway(
        transportFactory: (configuration) async {
          initializedProjectIds.add(configuration.projectId);
          return transports.removeAt(0);
        },
        now: () => now,
      );
      addTearDown(gateway.dispose);

      await gateway.initialize(_configuration);
      await gateway.reset();
      await gateway.initialize(
        WalletConnectConfiguration(
          projectId: 'replacement-project-id',
          metadata: _configuration.metadata,
        ),
      );

      expect(initializedProjectIds, ['project-id', 'replacement-project-id']);
      expect(firstTransport.clearPairingsCalls, 1);
      expect(firstTransport.disposeCalls, 1);
      expect(secondTransport.clearPairingsCalls, 0);
    },
  );
}

const _configuration = WalletConnectConfiguration(
  projectId: 'project-id',
  metadata: WalletConnectPeerMetadata(
    name: 'SafeWallet',
    description: 'Wallet',
    url: 'https://safewallet.app',
    icons: ['https://safewallet.app/icon.png'],
    nativeRedirect: 'safewallet://walletconnect',
  ),
);

const _peerMetadata = reown.PairingMetadata(
  name: 'Example dApp',
  description: 'Example',
  url: 'https://example.com',
  icons: ['https://example.com/icon.png'],
  redirect: reown.Redirect(native: 'example://wc'),
);

const _selfMetadata = reown.PairingMetadata(
  name: 'SafeWallet',
  description: 'Wallet',
  url: 'https://safewallet.app',
  icons: [],
);

final _sdkProposal = reown.ProposalData(
  id: 9,
  expiry: DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000,
  relays: [reown.Relay('irn')],
  proposer: const reown.ConnectionMetadata(
    publicKey: 'peer-key',
    metadata: _peerMetadata,
  ),
  requiredNamespaces: const {
    'eip155:1': reown.RequiredNamespace(
      methods: ['personal_sign'],
      events: ['accountsChanged'],
    ),
    'eip155': reown.RequiredNamespace(
      chains: ['eip155:56'],
      methods: ['eth_sendTransaction'],
      events: ['chainChanged'],
    ),
  },
  optionalNamespaces: const {},
  pairingTopic: 'pairing-a',
);

final _sdkSession = reown.SessionData(
  topic: 'topic-a',
  pairingTopic: 'pairing-a',
  relay: reown.Relay('irn'),
  expiry: DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000,
  acknowledged: true,
  controller: 'peer-key',
  namespaces: const {
    'eip155': reown.Namespace(
      chains: ['eip155:1'],
      accounts: ['eip155:1:0xabc'],
      methods: ['personal_sign'],
      events: ['accountsChanged'],
    ),
  },
  self: const reown.ConnectionMetadata(
    publicKey: 'self-key',
    metadata: _selfMetadata,
  ),
  peer: const reown.ConnectionMetadata(
    publicKey: 'peer-key',
    metadata: _peerMetadata,
  ),
);

final _sdkRequest = reown.SessionRequest(
  id: 7,
  topic: 'topic-a',
  chainId: 'eip155:1',
  method: 'personal_sign',
  params: const ['0x01', '0xabc'],
  verifyContext: const reown.VerifyContext(
    origin: 'https://example.com',
    validation: reown.Validation.VALID,
    verifyUrl: 'https://verify.walletconnect.com',
  ),
);

final class _FakeTransport implements ReownWalletKitTransport {
  _FakeTransport({
    Map<String, reown.SessionData>? sessions,
    Map<String, reown.ProposalData>? proposals,
    Map<String, reown.SessionRequest>? requests,
  }) : activeSessions = sessions ?? {},
       pendingProposals = proposals ?? {},
       pendingRequests = requests ?? {};

  final Map<String, reown.SessionData> activeSessions;
  final Map<String, reown.ProposalData> pendingProposals;
  final Map<String, reown.SessionRequest> pendingRequests;
  final proposalController =
      StreamController<reown.SessionProposalEvent>.broadcast();
  final proposalExpiredController = StreamController<int>.broadcast();
  final proposalsChangedController = StreamController<void>.broadcast();
  final requestController =
      StreamController<reown.SessionRequestEvent>.broadcast();
  final sessionsChangedController = StreamController<void>.broadcast();
  final sessionDeletedController = StreamController<String>.broadcast();
  final approvedNamespaces = <Map<String, reown.Namespace>>[];
  final responses = <({String topic, reown.JsonRpcResponse response})>[];
  final rejectionReasons = <reown.ReownSignError>[];
  final disconnectReasons = <reown.ReownSignError>[];
  int automaticHandlerRegistrations = 0;
  int clearPairingsCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<reown.SessionProposalEvent> get proposals => proposalController.stream;

  @override
  Stream<int> get proposalExpired => proposalExpiredController.stream;

  @override
  Stream<void> get proposalsChanged => proposalsChangedController.stream;

  @override
  Stream<reown.SessionRequestEvent> get requests => requestController.stream;

  @override
  Stream<void> get sessionsChanged => sessionsChangedController.stream;

  @override
  Stream<String> get sessionDeleted => sessionDeletedController.stream;

  @override
  Map<String, reown.SessionData> getActiveSessions() => activeSessions;

  @override
  Map<String, reown.ProposalData> getPendingSessionProposals() =>
      pendingProposals;

  @override
  Map<String, reown.SessionRequest> getPendingSessionRequests() =>
      pendingRequests;

  @override
  Future<void> pair(Uri uri) async {}

  @override
  Future<void> approveSession(
    int id,
    Map<String, reown.Namespace> namespaces,
  ) async {
    approvedNamespaces.add(namespaces);
  }

  @override
  Future<void> rejectSession(int id, reown.ReownSignError reason) async {
    rejectionReasons.add(reason);
  }

  @override
  Future<void> respondSessionRequest(
    String topic,
    reown.JsonRpcResponse response,
  ) async {
    responses.add((topic: topic, response: response));
  }

  @override
  Future<void> disconnectSession(
    String topic,
    reown.ReownSignError reason,
  ) async {
    disconnectReasons.add(reason);
  }

  @override
  Future<void> clearPairings() async {
    clearPairingsCalls += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await proposalController.close();
    await proposalExpiredController.close();
    await proposalsChangedController.close();
    await requestController.close();
    await sessionsChangedController.close();
    await sessionDeletedController.close();
  }
}
