enum TokenSource {
  builtIn,
  userAdded,
  discovered,
}

final class TokenInfo {
  const TokenInfo({
    required this.chainId,
    required this.contractAddress,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.source,
    required this.isHidden,
    this.logoUri,
    this.requiresMemo = false,
    this.memoLabel,
  });

  final String chainId;
  final String? contractAddress;
  final String symbol;
  final String name;
  final int decimals;
  final String? logoUri;
  final TokenSource source;
  final bool isHidden;
  final bool requiresMemo;
  final String? memoLabel;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TokenInfo &&
            other.chainId == chainId &&
            other.contractAddress == contractAddress &&
            other.symbol == symbol &&
            other.name == name &&
            other.decimals == decimals &&
            other.logoUri == logoUri &&
            other.source == source &&
            other.isHidden == isHidden &&
            other.requiresMemo == requiresMemo &&
            other.memoLabel == memoLabel;
  }

  @override
  int get hashCode {
    return Object.hash(
      chainId,
      contractAddress,
      symbol,
      name,
      decimals,
      logoUri,
      source,
      isHidden,
      requiresMemo,
      memoLabel,
    );
  }
}
