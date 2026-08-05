enum SecurityLogEventType {
  viewMnemonic,
  viewPrivateKey,
  copyMnemonic,
  copyPrivateKey,
  createWallet,
  importWallet,
  deleteWallet,
  changePassword,
  signMessage,
  signTransaction,
  wrapNative,
  unwrapNative,
  solanaRentRecovery,
  tronStake,
  tronUnstake,
  tronWithdrawUnfreeze,
  tronCancelUnfreeze,
  tronDelegateResource,
  tronUndelegateResource,
  tronVote,
  tronClaimReward,
}

final class SecurityLogEntry {
  const SecurityLogEntry({
    required this.type,
    required this.occurredAt,
    this.walletName,
    this.chainName,
    this.assetSymbol,
    this.amount,
    this.address,
  });

  final SecurityLogEventType type;
  final DateTime occurredAt;
  final String? walletName;
  final String? chainName;
  final String? assetSymbol;
  final String? amount;
  final String? address;

  @override
  bool operator ==(Object other) {
    return other is SecurityLogEntry &&
        other.type == type &&
        other.occurredAt == occurredAt &&
        other.walletName == walletName &&
        other.chainName == chainName &&
        other.assetSymbol == assetSymbol &&
        other.amount == amount &&
        other.address == address;
  }

  @override
  int get hashCode => Object.hash(
    type,
    occurredAt,
    walletName,
    chainName,
    assetSymbol,
    amount,
    address,
  );
}
