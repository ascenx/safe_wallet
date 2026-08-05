import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_controller.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_project_id_setting.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_response_outbox.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';

void main() {
  const buildProjectId = '11111111111111111111111111111111';
  const customProjectId = '22222222222222222222222222222222';

  test(
    'reports missing configuration without initializing transport',
    () async {
      final gateway = _FakeGateway();
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue(''),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(walletConnectControllerProvider.notifier)
          .initialize();

      expect(gateway.initializeCalls, 0);
      expect(
        container.read(walletConnectControllerProvider).status,
        WalletConnectStatus.missingConfiguration,
      );
    },
  );

  test('initializes once and restores active sessions', () async {
    final gateway = _FakeGateway(sessions: [_session('topic-a')]);
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectProjectIdProvider.overrideWithValue('project-id'),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(walletConnectControllerProvider.notifier);
    await controller.initialize();
    await controller.initialize();

    expect(gateway.initializeCalls, 1);
    expect(
      container.read(walletConnectControllerProvider).status,
      WalletConnectStatus.ready,
    );
    expect(
      container.read(walletConnectControllerProvider).sessions.single.topic,
      'topic-a',
    );
  });

  test(
    'restores pending proposals and requests after transport initialize',
    () async {
      final gateway = _FakeGateway(
        sessions: [_session('topic-a')],
        pendingProposals: [_proposal],
        pendingRequests: [_request(7, topic: 'topic-a')],
      );
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        walletConnectControllerProvider.notifier,
      );
      await controller.initialize();

      expect(
        container.read(walletConnectControllerProvider).pendingProposal?.id,
        9,
      );
      expect(controller.requestQueue.activeRequest?.id, 7);
    },
  );

  test(
    'restored expired requests are persisted when the response fails',
    () async {
      final outbox = InMemoryWalletConnectResponseOutbox();
      final gateway = _FakeGateway(
        pendingRequests: [
          _request(7, topic: 'topic-a', expiry: DateTime.utc(2020)),
        ],
        respondError: StateError('offline'),
      );
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
          walletConnectResponseOutboxProvider.overrideWithValue(outbox),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(walletConnectControllerProvider.notifier)
          .initialize();

      final pending = await outbox.list();
      expect(pending, hasLength(1));
      expect(pending.single.topic, 'topic-a');
      expect(pending.single.response.error?.code, 8000);
    },
  );

  test('initialization flushes persisted error responses', () async {
    final outbox = InMemoryWalletConnectResponseOutbox();
    await outbox.put(
      WalletConnectErrorResponse(
        topic: 'topic-a',
        response: const WalletConnectResponse.error(
          id: 7,
          error: WalletConnectResponseError(
            code: -32000,
            message: 'Request failed',
          ),
        ),
        createdAt: DateTime.now(),
      ),
    );
    final gateway = _FakeGateway();
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectProjectIdProvider.overrideWithValue('project-id'),
        walletConnectResponseOutboxProvider.overrideWithValue(outbox),
      ],
    );
    addTearDown(container.dispose);

    await container.read(walletConnectControllerProvider.notifier).initialize();

    expect(gateway.responses, hasLength(1));
    expect(gateway.responses.single.response.error?.code, -32000);
    expect(await outbox.list(), isEmpty);
  });

  test('validates pairing URI without exposing it to an error', () async {
    final gateway = _FakeGateway();
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectProjectIdProvider.overrideWithValue('project-id'),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(walletConnectControllerProvider.notifier);
    await controller.initialize();

    expect(
      await controller.pair('https://example.com'),
      WalletConnectPairResult.invalidUri,
    );
    expect(gateway.pairedUris, isEmpty);

    expect(
      await controller.pair('wc:topic@2?symKey=secret'),
      WalletConnectPairResult.accepted,
    );
    expect(gateway.pairedUris, hasLength(1));
    expect(
      await controller.pair('wc:topic@2?symKey=secret'),
      WalletConnectPairResult.duplicate,
    );
    expect(gateway.pairedUris, hasLength(1));
  });

  test(
    'pairing URI fingerprint is stable and does not use String hashCode',
    () async {
      const firstUri = 'wc:topic@2?symKey=secret';
      const secondUri = 'wc:topic@2?symKey=other';

      final first = await walletConnectPairingUriFingerprint(firstUri);

      expect(await walletConnectPairingUriFingerprint(firstUri), first);
      expect(await walletConnectPairingUriFingerprint(secondUri), isNot(first));
      expect(first, hasLength(43));
      expect(first, isNot(firstUri.hashCode.toString()));
    },
  );

  test(
    'stores proposals and clears them when the SDK reports expiry',
    () async {
      final gateway = _FakeGateway();
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(walletConnectControllerProvider.notifier)
          .initialize();

      gateway.proposalController.add(_proposal);
      await pumpEventQueue();
      expect(
        container.read(walletConnectControllerProvider).pendingProposal?.id,
        9,
      );

      gateway.proposalExpiredController.add(9);
      await pumpEventQueue();
      expect(
        container.read(walletConnectControllerProvider).pendingProposal,
        isNull,
      );
    },
  );

  test('clears a proposal when its pairing is deleted', () async {
    final gateway = _FakeGateway(pendingProposals: [_proposal]);
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectProjectIdProvider.overrideWithValue('project-id'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(walletConnectControllerProvider.notifier).initialize();
    expect(
      container.read(walletConnectControllerProvider).pendingProposal?.id,
      9,
    );

    gateway.pendingProposals.clear();
    gateway.proposalsChangedController.add(null);
    await pumpEventQueue();

    expect(
      container.read(walletConnectControllerProvider).pendingProposal,
      isNull,
    );
  });

  test(
    'shows the next pending proposal after approving the current one',
    () async {
      final second = WalletConnectProposal(
        id: 10,
        pairingTopic: 'pairing-b',
        peer: _proposal.peer,
        requiredNamespaces: const {},
        optionalNamespaces: const {},
        expiry: DateTime.utc(2031),
      );
      final gateway = _FakeGateway(pendingProposals: [_proposal, second]);
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        walletConnectControllerProvider.notifier,
      );
      await controller.initialize();

      await controller.approveProposal(const {});

      expect(
        container.read(walletConnectControllerProvider).pendingProposal?.id,
        10,
      );
    },
  );

  test(
    'session events refresh state and deleted topics cancel requests',
    () async {
      final gateway = _FakeGateway();
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        walletConnectControllerProvider.notifier,
      );
      await controller.initialize();

      gateway.sessions = [_session('topic-a')];
      gateway.sessionsChangedController.add(null);
      gateway.requestController.add(_request(1, topic: 'topic-a'));
      gateway.requestController.add(_request(2, topic: 'topic-a'));
      await pumpEventQueue();

      expect(
        container.read(walletConnectControllerProvider).sessions,
        hasLength(1),
      );
      expect(controller.requestQueue.activeRequest?.id, 1);
      gateway.deletedController.add('topic-a');
      await pumpEventQueue();

      expect(controller.requestQueue.activeRequest, isNull);
      expect(controller.requestQueue.pendingCount, 0);
    },
  );

  test('disconnect and disconnect all call the gateway', () async {
    final gateway = _FakeGateway(
      sessions: [_session('topic-a'), _session('topic-b')],
    );
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectProjectIdProvider.overrideWithValue('project-id'),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(walletConnectControllerProvider.notifier);
    await controller.initialize();

    await controller.disconnect('topic-a');
    await controller.disconnectAll();

    expect(gateway.disconnectedTopics, ['topic-a', 'topic-b']);
  });

  test(
    'reconfigures the existing runtime with the latest Project ID',
    () async {
      final gateway = _FakeGateway();
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectBuildProjectIdProvider.overrideWithValue(buildProjectId),
          walletConnectProjectIdStoreProvider.overrideWithValue(
            InMemoryWalletConnectProjectIdStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        walletConnectControllerProvider.notifier,
      );
      await controller.initialize();
      await container
          .read(walletConnectProjectIdSettingProvider.notifier)
          .setCustomProjectId(customProjectId);

      final applied = await controller.reconfigure();

      expect(applied, isTrue);
      expect(gateway.resetCalls, 1);
      expect(gateway.initializedProjectIds, [buildProjectId, customProjectId]);
      expect(
        container.read(walletConnectControllerProvider).status,
        WalletConnectStatus.ready,
      );
    },
  );

  test(
    'reconfiguring without a fallback disables the runtime immediately',
    () async {
      final gateway = _FakeGateway();
      final store = InMemoryWalletConnectProjectIdStore(
        projectId: customProjectId,
      );
      final container = ProviderContainer(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectBuildProjectIdProvider.overrideWithValue(''),
          walletConnectProjectIdStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        walletConnectControllerProvider.notifier,
      );
      await controller.initialize();
      await container
          .read(walletConnectProjectIdSettingProvider.notifier)
          .deleteCustomProjectId();

      final applied = await controller.reconfigure();

      expect(applied, isTrue);
      expect(gateway.resetCalls, 1);
      expect(gateway.initializedProjectIds, [customProjectId]);
      expect(
        container.read(walletConnectControllerProvider).status,
        WalletConnectStatus.missingConfiguration,
      );
    },
  );

  test('reconfiguring cancels requests from the previous runtime', () async {
    final gateway = _FakeGateway(
      pendingRequests: [_request(7, topic: 'topic-a')],
    );
    final container = ProviderContainer(
      overrides: [
        walletConnectGatewayProvider.overrideWithValue(gateway),
        walletConnectBuildProjectIdProvider.overrideWithValue(buildProjectId),
        walletConnectProjectIdStoreProvider.overrideWithValue(
          InMemoryWalletConnectProjectIdStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(walletConnectControllerProvider.notifier);
    final cancelledRequests = <WalletConnectRequest>[];
    final cancellationSubscription = controller.requestQueue.cancelledRequests
        .listen(cancelledRequests.add);
    addTearDown(cancellationSubscription.cancel);
    await controller.initialize();
    await container
        .read(walletConnectProjectIdSettingProvider.notifier)
        .setCustomProjectId(customProjectId);

    await controller.reconfigure();

    expect(cancelledRequests.map((request) => request.id), [7]);
    expect(controller.requestQueue.activeRequest, isNull);
    expect(controller.requestQueue.pendingCount, 0);
  });
}

WalletConnectSession _session(String topic) => WalletConnectSession(
  topic: topic,
  pairingTopic: 'pairing-$topic',
  peer: const WalletConnectPeerMetadata(
    name: 'Example dApp',
    description: 'Example',
    url: 'https://example.com',
    icons: [],
  ),
  namespaces: const {},
  expiry: DateTime.utc(2030),
  createdAt: DateTime.utc(2026),
);

WalletConnectRequest _request(
  int id, {
  required String topic,
  DateTime? expiry,
}) => WalletConnectRequest(
  id: id,
  topic: topic,
  chain: const Caip2ChainId(namespace: 'eip155', reference: '1'),
  method: 'personal_sign',
  params: const [],
  peer: const WalletConnectPeerMetadata(
    name: 'Example dApp',
    description: 'Example',
    url: 'https://example.com',
    icons: [],
  ),
  expiry: expiry ?? DateTime.utc(2030),
);

final class _FakeGateway implements WalletConnectGateway {
  _FakeGateway({
    List<WalletConnectSession>? sessions,
    List<WalletConnectProposal>? pendingProposals,
    List<WalletConnectRequest>? pendingRequests,
    this.respondError,
  }) : sessions = sessions ?? [],
       pendingProposals = pendingProposals ?? [],
       pendingRequests = pendingRequests ?? [];

  int initializeCalls = 0;
  int resetCalls = 0;
  final initializedProjectIds = <String>[];
  List<WalletConnectSession> sessions;
  final List<WalletConnectProposal> pendingProposals;
  final List<WalletConnectRequest> pendingRequests;
  final Object? respondError;
  final pairedUris = <Uri>[];
  final disconnectedTopics = <String>[];
  final responses = <({String topic, WalletConnectResponse response})>[];
  final proposalController =
      StreamController<WalletConnectProposal>.broadcast();
  final proposalExpiredController = StreamController<int>.broadcast();
  final requestController = StreamController<WalletConnectRequest>.broadcast();
  final proposalsChangedController = StreamController<void>.broadcast();
  final sessionsChangedController = StreamController<void>.broadcast();
  final deletedController = StreamController<String>.broadcast();

  @override
  Stream<WalletConnectProposal> get proposals => proposalController.stream;

  @override
  Stream<int> get proposalExpired => proposalExpiredController.stream;

  @override
  Stream<WalletConnectRequest> get requests => requestController.stream;

  @override
  Stream<void> get proposalsChanged => proposalsChangedController.stream;

  @override
  Stream<void> get sessionsChanged => sessionsChangedController.stream;

  @override
  Stream<String> get sessionDeleted => deletedController.stream;

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {
    initializeCalls += 1;
    initializedProjectIds.add(configuration.projectId);
  }

  @override
  Future<void> reset() async {
    resetCalls += 1;
    sessions = [];
    pendingProposals.clear();
    pendingRequests.clear();
  }

  @override
  Future<void> pair(Uri uri) async => pairedUris.add(uri);

  @override
  Future<List<WalletConnectSession>> getActiveSessions() async =>
      List.of(sessions);

  @override
  Future<List<WalletConnectProposal>> getPendingProposals() async =>
      List.of(pendingProposals);

  @override
  Future<List<WalletConnectRequest>> getPendingRequests() async =>
      List.of(pendingRequests);

  @override
  Future<void> disconnect(String topic) async {
    disconnectedTopics.add(topic);
    sessions.removeWhere((session) => session.topic == topic);
  }

  @override
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) async {
    pendingProposals.removeWhere((proposal) => proposal.id == id);
  }

  @override
  Future<void> rejectProposal(int id) async {
    pendingProposals.removeWhere((proposal) => proposal.id == id);
  }

  @override
  Future<void> respond(String topic, WalletConnectResponse response) async {
    final error = respondError;
    if (error != null) {
      throw error;
    }
    responses.add((topic: topic, response: response));
  }

  @override
  Future<void> dispose() async {
    await proposalController.close();
    await proposalExpiredController.close();
    await requestController.close();
    await proposalsChangedController.close();
    await sessionsChangedController.close();
    await deletedController.close();
  }
}

final _proposal = WalletConnectProposal(
  id: 9,
  pairingTopic: 'pairing-a',
  peer: const WalletConnectPeerMetadata(
    name: 'Example dApp',
    description: 'Example',
    url: 'https://example.com',
    icons: [],
  ),
  requiredNamespaces: const {},
  optionalNamespaces: const {},
  expiry: DateTime.utc(2030),
);
