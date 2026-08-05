import 'wallet_connect_caip.dart';
import 'wallet_connect_namespace.dart';

final class WalletConnectPeerMetadata {
  const WalletConnectPeerMetadata({
    required this.name,
    required this.description,
    required this.url,
    required this.icons,
    this.nativeRedirect,
    this.universalRedirect,
  });

  final String name;
  final String description;
  final String url;
  final List<String> icons;
  final String? nativeRedirect;
  final String? universalRedirect;
}

enum WalletConnectVerifyStatus { unknown, valid, invalid, scam }

final class WalletConnectVerifyContext {
  const WalletConnectVerifyContext({
    required this.origin,
    required this.status,
    this.verifyUrl,
  });

  final String origin;
  final WalletConnectVerifyStatus status;
  final String? verifyUrl;

  bool get blocksApproval =>
      status == WalletConnectVerifyStatus.invalid ||
      status == WalletConnectVerifyStatus.scam;
}

final class WalletConnectProposal {
  const WalletConnectProposal({
    required this.id,
    required this.pairingTopic,
    required this.peer,
    required this.requiredNamespaces,
    required this.optionalNamespaces,
    required this.expiry,
    this.verifyContext,
  });

  final int id;
  final String pairingTopic;
  final WalletConnectPeerMetadata peer;
  final Map<String, WalletConnectNamespaceProposal> requiredNamespaces;
  final Map<String, WalletConnectNamespaceProposal> optionalNamespaces;
  final DateTime expiry;
  final WalletConnectVerifyContext? verifyContext;

  bool isExpiredAt(DateTime value) => !expiry.isAfter(value);
}

final class WalletConnectSession {
  const WalletConnectSession({
    required this.topic,
    required this.pairingTopic,
    required this.peer,
    required this.namespaces,
    required this.expiry,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String topic;
  final String pairingTopic;
  final WalletConnectPeerMetadata peer;
  final Map<String, WalletConnectApprovedNamespace> namespaces;
  final DateTime expiry;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  bool isExpiredAt(DateTime value) => !expiry.isAfter(value);
}

final class WalletConnectRequest {
  const WalletConnectRequest({
    required this.id,
    required this.topic,
    required this.chain,
    required this.method,
    required this.params,
    required this.peer,
    required this.expiry,
    this.verifyContext,
  });

  final int id;
  final String topic;
  final Caip2ChainId chain;
  final String method;
  final Object? params;
  final WalletConnectPeerMetadata peer;
  final DateTime expiry;
  final WalletConnectVerifyContext? verifyContext;

  String get dedupeKey => '$topic:$id';

  bool isExpiredAt(DateTime value) => !expiry.isAfter(value);
}

final class WalletConnectResponse {
  const WalletConnectResponse.success({required this.id, required this.result})
    : error = null;

  const WalletConnectResponse.error({required this.id, required this.error})
    : result = null;

  final int id;
  final Object? result;
  final WalletConnectResponseError? error;
}

final class WalletConnectResponseError {
  const WalletConnectResponseError({required this.code, required this.message});

  final int code;
  final String message;
}
