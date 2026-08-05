final class DappPermission {
  const DappPermission({
    required this.id,
    required this.domain,
    required this.walletId,
    required this.chainId,
    required this.address,
    required this.grantedAt,
    required this.lastUsedAt,
    this.expiresAt,
  });

  final String id;
  final String domain;
  final String walletId;
  final String chainId;
  final String address;
  final DateTime grantedAt;
  final DateTime lastUsedAt;
  final DateTime? expiresAt;

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DappPermission &&
            other.id == id &&
            other.domain == domain &&
            other.walletId == walletId &&
            other.chainId == chainId &&
            other.address == address &&
            other.grantedAt == grantedAt &&
            other.lastUsedAt == lastUsedAt &&
            other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      domain,
      walletId,
      chainId,
      address,
      grantedAt,
      lastUsedAt,
      expiresAt,
    );
  }
}
