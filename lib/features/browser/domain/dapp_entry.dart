enum DappCategory {
  swap,
  predictions,
  staking,
  bridge,
  defi,
  nft,
  tool,
}

enum DappSwapType {
  aggregator,
  dex,
  meme,
  crossChain,
}

enum DappRiskLevel {
  standard,
  high,
}

final class DappEntry {
  const DappEntry({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.supportedChainIds,
    required this.isFavorite,
    this.isDefault = false,
    this.iconUrl,
    this.lastVisitedAt,
    this.swapType,
    this.riskLevel = DappRiskLevel.standard,
  });

  final String id;
  final String name;
  final String url;
  final DappCategory category;
  final List<String> supportedChainIds;
  final bool isFavorite;
  final bool isDefault;
  final String? iconUrl;
  final DateTime? lastVisitedAt;
  final DappSwapType? swapType;
  final DappRiskLevel riskLevel;

  DappEntry copyWith({
    bool? isFavorite,
    bool? isDefault,
    DateTime? lastVisitedAt,
  }) {
    return DappEntry(
      id: id,
      name: name,
      url: url,
      category: category,
      supportedChainIds: supportedChainIds,
      isFavorite: isFavorite ?? this.isFavorite,
      isDefault: isDefault ?? this.isDefault,
      iconUrl: iconUrl,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      swapType: swapType,
      riskLevel: riskLevel,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DappEntry &&
            other.id == id &&
            other.name == name &&
            other.url == url &&
            other.category == category &&
            _stringListsEqual(other.supportedChainIds, supportedChainIds) &&
            other.isFavorite == isFavorite &&
            other.isDefault == isDefault &&
            other.iconUrl == iconUrl &&
            other.lastVisitedAt == lastVisitedAt &&
            other.swapType == swapType &&
            other.riskLevel == riskLevel;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      url,
      category,
      Object.hashAll(supportedChainIds),
      isFavorite,
      isDefault,
      iconUrl,
      lastVisitedAt,
      swapType,
      riskLevel,
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
