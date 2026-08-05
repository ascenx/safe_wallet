enum SolanaRentTokenProgram {
  splToken,
  token2022,
}

final class SolanaRentAccount {
  const SolanaRentAccount({
    required this.address,
    required this.mintAddress,
    required this.program,
    required this.recoverableLamports,
  });

  final String address;
  final String mintAddress;
  final SolanaRentTokenProgram program;
  final BigInt recoverableLamports;
}

final class SolanaRentScanResult {
  SolanaRentScanResult({
    required List<SolanaRentAccount> accounts,
    required this.solBalanceLamports,
  }) : accounts = List.unmodifiable(accounts);

  final List<SolanaRentAccount> accounts;
  final BigInt solBalanceLamports;

  BigInt get totalRecoverableLamports => accounts.fold(
        BigInt.zero,
        (sum, account) => sum + account.recoverableLamports,
      );
}

final class SolanaRentRecoveryBatch {
  SolanaRentRecoveryBatch({
    required List<SolanaRentAccount> accounts,
    BigInt? estimatedFeeLamports,
  })  : accounts = List.unmodifiable(accounts),
        estimatedFeeLamports = estimatedFeeLamports ?? BigInt.zero;

  final List<SolanaRentAccount> accounts;
  final BigInt estimatedFeeLamports;
}

final class SolanaRentRecoveryEstimate {
  SolanaRentRecoveryEstimate({
    required List<SolanaRentRecoveryBatch> batches,
  }) : batches = List.unmodifiable(batches);

  final List<SolanaRentRecoveryBatch> batches;

  BigInt get totalRecoverableLamports =>
      batches.expand((batch) => batch.accounts).fold(
            BigInt.zero,
            (sum, account) => sum + account.recoverableLamports,
          );

  BigInt get networkFeeLamports => batches.fold(
        BigInt.zero,
        (sum, batch) => sum + batch.estimatedFeeLamports,
      );

  BigInt get netRecoverableLamports =>
      totalRecoverableLamports - networkFeeLamports;
}

final class SolanaRentRecoveryResult {
  SolanaRentRecoveryResult({
    required List<String> signatures,
    required this.completedAccountCount,
    required this.recoveredLamports,
    this.errorMessage,
  }) : signatures = List.unmodifiable(signatures);

  final List<String> signatures;
  final int completedAccountCount;
  final BigInt recoveredLamports;
  final String? errorMessage;

  bool get isPartial => errorMessage != null && signatures.isNotEmpty;
  bool get isSuccess => errorMessage == null;
}

String formatSolLamports(BigInt lamports) {
  final whole = lamports ~/ BigInt.from(1000000000);
  final fraction = (lamports % BigInt.from(1000000000))
      .abs()
      .toString()
      .padLeft(9, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final sign = lamports.isNegative && whole == BigInt.zero ? '-' : '';
  return fraction.isEmpty ? '$whole' : '$sign$whole.$fraction';
}
