import 'token_info.dart';

enum AssetBalanceStatus {
  loading,
  loaded,
  failed,
}

final class AssetBalance {
  const AssetBalance({
    required this.chainId,
    required this.token,
    required this.balance,
    required this.formattedBalance,
    required this.status,
    this.errorMessage,
    this.fiatValue,
    this.fiatValueUsd,
    this.priceUsd,
  });

  final String chainId;
  final TokenInfo token;
  final String? balance;
  final String? formattedBalance;
  final AssetBalanceStatus status;
  final String? errorMessage;
  final String? fiatValue;
  final double? fiatValueUsd;
  final double? priceUsd;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AssetBalance &&
            other.chainId == chainId &&
            other.token == token &&
            other.balance == balance &&
            other.formattedBalance == formattedBalance &&
            other.status == status &&
            other.errorMessage == errorMessage &&
            other.fiatValue == fiatValue &&
            other.fiatValueUsd == fiatValueUsd &&
            other.priceUsd == priceUsd;
  }

  @override
  int get hashCode {
    return Object.hash(
      chainId,
      token,
      balance,
      formattedBalance,
      status,
      errorMessage,
      fiatValue,
      fiatValueUsd,
      priceUsd,
    );
  }
}
