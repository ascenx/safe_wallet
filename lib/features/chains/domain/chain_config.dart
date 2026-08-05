enum ChainType {
  evm,
  bitcoin,
  tron,
  solana,
  sui,
}

final class ChainConfig {
  const ChainConfig({
    required this.id,
    required this.chainType,
    required this.name,
    required this.chainId,
    required this.symbol,
    required this.rpcUrls,
    required this.blockExplorerUrl,
    required this.isTestnet,
  });

  final String id;
  final ChainType chainType;
  final String name;
  final String chainId;
  final String symbol;
  final List<String> rpcUrls;
  final String? blockExplorerUrl;
  final bool isTestnet;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChainConfig &&
            other.id == id &&
            other.chainType == chainType &&
            other.name == name &&
            other.chainId == chainId &&
            other.symbol == symbol &&
            _stringListsEqual(other.rpcUrls, rpcUrls) &&
            other.blockExplorerUrl == blockExplorerUrl &&
            other.isTestnet == isTestnet;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chainType,
      name,
      chainId,
      symbol,
      Object.hashAll(rpcUrls),
      blockExplorerUrl,
      isTestnet,
    );
  }
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
