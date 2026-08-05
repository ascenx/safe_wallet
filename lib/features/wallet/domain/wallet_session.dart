final class WalletSession {
  const WalletSession({
    required this.walletId,
    required this.isUnlocked,
    required this.unlockedUntil,
  });

  final String walletId;
  final bool isUnlocked;
  final DateTime? unlockedUntil;

  bool isExpired(DateTime now) {
    final expiresAt = unlockedUntil;
    return !isUnlocked || (expiresAt != null && !expiresAt.isAfter(now));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WalletSession &&
            other.walletId == walletId &&
            other.isUnlocked == isUnlocked &&
            other.unlockedUntil == unlockedUntil;
  }

  @override
  int get hashCode => Object.hash(walletId, isUnlocked, unlockedUntil);
}
