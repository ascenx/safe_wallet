enum RpcNodeType {
  defaultNode,
  chainlist,
  custom,
}

enum RpcNodeTestStatus {
  untested,
  testing,
  available,
  unavailable,
}

enum RpcProvider {
  public,
  custom,
  helius,
  quickNode,
  alchemy,
  infura,
  tronGrid,
}

enum RpcCredentialMode {
  none,
  queryParameter,
  pathSegment,
  header,
  fullEndpoint,
}

final class RpcNode {
  const RpcNode({
    required this.id,
    required this.chainId,
    required this.name,
    required this.url,
    required this.nodeType,
    required this.isSelected,
    required this.lastTestStatus,
    this.lastTestedAt,
    this.lastBlockHeight,
    this.lastLatencyMs,
    this.note,
    this.provider = RpcProvider.custom,
    this.credentialMode = RpcCredentialMode.none,
    this.credentialParameter,
    this.credentialRef,
    this.resolvedUrl,
    this.resolvedHeaders = const {},
  });

  final String id;
  final String chainId;
  final String name;
  final String url;
  final RpcNodeType nodeType;
  final bool isSelected;
  final RpcNodeTestStatus lastTestStatus;
  final DateTime? lastTestedAt;
  final int? lastBlockHeight;
  final int? lastLatencyMs;
  final String? note;
  final RpcProvider provider;
  final RpcCredentialMode credentialMode;
  final String? credentialParameter;
  final String? credentialRef;
  final String? resolvedUrl;
  final Map<String, String> resolvedHeaders;

  String get endpointUrl => resolvedUrl ?? url;

  Map<String, String> get endpointHeaders => resolvedHeaders;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RpcNode &&
            other.id == id &&
            other.chainId == chainId &&
            other.name == name &&
            other.url == url &&
            other.nodeType == nodeType &&
            other.isSelected == isSelected &&
            other.lastTestStatus == lastTestStatus &&
            other.lastTestedAt == lastTestedAt &&
            other.lastBlockHeight == lastBlockHeight &&
            other.lastLatencyMs == lastLatencyMs &&
            other.note == note &&
            other.provider == provider &&
            other.credentialMode == credentialMode &&
            other.credentialParameter == credentialParameter &&
            other.credentialRef == credentialRef &&
            other.resolvedUrl == resolvedUrl &&
            _stringMapsEqual(other.resolvedHeaders, resolvedHeaders);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chainId,
      name,
      url,
      nodeType,
      isSelected,
      lastTestStatus,
      lastTestedAt,
      lastBlockHeight,
      lastLatencyMs,
      note,
      provider,
      credentialMode,
      credentialParameter,
      credentialRef,
      resolvedUrl,
      Object.hashAllUnordered(resolvedHeaders.entries),
    );
  }
}

bool _stringMapsEqual(
  Map<String, String> left,
  Map<String, String> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
