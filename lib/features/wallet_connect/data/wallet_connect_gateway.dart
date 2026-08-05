import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_walletkit/reown_walletkit.dart' as reown;

import '../domain/wallet_connect_caip.dart';
import '../domain/wallet_connect_models.dart';
import '../domain/wallet_connect_namespace.dart';

part 'reown_wallet_connect_gateway.dart';

final class WalletConnectConfiguration {
  const WalletConnectConfiguration({
    required this.projectId,
    required this.metadata,
  });

  final String projectId;
  final WalletConnectPeerMetadata metadata;
}

abstract interface class WalletConnectGateway {
  Stream<WalletConnectProposal> get proposals;
  Stream<int> get proposalExpired;
  Stream<void> get proposalsChanged;
  Stream<WalletConnectRequest> get requests;
  Stream<void> get sessionsChanged;
  Stream<String> get sessionDeleted;

  Future<void> initialize(WalletConnectConfiguration configuration);
  Future<void> reset();
  Future<void> pair(Uri uri);
  Future<List<WalletConnectSession>> getActiveSessions();
  Future<List<WalletConnectProposal>> getPendingProposals();
  Future<List<WalletConnectRequest>> getPendingRequests();
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  );
  Future<void> rejectProposal(int id);
  Future<void> respond(String topic, WalletConnectResponse response);
  Future<void> disconnect(String topic);
  Future<void> dispose();
}

final walletConnectGatewayProvider = Provider<WalletConnectGateway>((ref) {
  final gateway = ReownWalletConnectGateway();
  ref.onDispose(() => unawaited(gateway.dispose()));
  return gateway;
});

base class UnsupportedWalletConnectGateway implements WalletConnectGateway {
  const UnsupportedWalletConnectGateway();

  @override
  Stream<WalletConnectProposal> get proposals => const Stream.empty();

  @override
  Stream<int> get proposalExpired => const Stream.empty();

  @override
  Stream<void> get proposalsChanged => const Stream.empty();

  @override
  Stream<WalletConnectRequest> get requests => const Stream.empty();

  @override
  Stream<String> get sessionDeleted => const Stream.empty();

  @override
  Stream<void> get sessionsChanged => const Stream.empty();

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<void> reset() async {}

  @override
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<void> disconnect(String topic) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<List<WalletConnectSession>> getActiveSessions() async => const [];

  @override
  Future<List<WalletConnectProposal>> getPendingProposals() async => const [];

  @override
  Future<List<WalletConnectRequest>> getPendingRequests() async => const [];

  @override
  Future<void> pair(Uri uri) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<void> rejectProposal(int id) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<void> respond(String topic, WalletConnectResponse response) {
    throw StateError('wallet_connect_transport_unavailable');
  }

  @override
  Future<void> dispose() async {}
}
