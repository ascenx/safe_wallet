import 'package:solana_sdk/solana_sdk.dart';

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/header_http_client.dart';

typedef SolanaConnectionFactory = Connection Function(String rpcUrl);

final class SolanaFeeEstimate {
  const SolanaFeeEstimate({
    required this.lamports,
    required this.recentBlockhash,
    this.computeUnitLimit,
    this.priorityFeeOptionsMicroLamports = const [],
  });

  final BigInt lamports;
  final String recentBlockhash;
  final int? computeUnitLimit;
  final List<BigInt> priorityFeeOptionsMicroLamports;
}

abstract interface class SolanaFeeService {
  Future<SolanaFeeEstimate> estimateSolTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt lamports,
    Map<String, String> headers = const {},
  });
}

final class SdkSolanaFeeService implements SolanaFeeService {
  const SdkSolanaFeeService({this.connectionFactory});

  final SolanaConnectionFactory? connectionFactory;

  @override
  Future<SolanaFeeEstimate> estimateSolTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt lamports,
    Map<String, String> headers = const {},
  }) async {
    final connection =
        connectionFactory?.call(rpcUrl) ??
        _createSolanaConnection(rpcUrl, headers);
    try {
      final blockhash = await connection.getLatestBlockhash();
      final transaction =
          Transaction(
            feePayer: PublicKey.fromBase58(fromAddress),
            recentBlockhash: blockhash.blockhash,
          )..add(
            SystemProgram.transfer(
              fromPubkey: PublicKey.fromBase58(fromAddress),
              toPubkey: PublicKey.fromBase58(toAddress),
              lamports: lamports,
            ),
          );
      final fee = await transaction.getEstimatedFee(connection);
      if (fee == null) {
        throw StateError('Solana fee estimate returned null');
      }
      final simulation = await connection.simulateTransaction(
        transaction,
        sigVerify: false,
        replaceRecentBlockhash: true,
      );
      if (simulation.value.err != null) {
        throw StateError('Solana transaction simulation failed');
      }
      final consumed = simulation.value.unitsConsumed;
      if (consumed == null || consumed <= 0) {
        throw StateError('Solana simulation returned no compute units');
      }
      final computeUnitLimit = (consumed * 11 + 9) ~/ 10;
      final recentFees = await connection.getRecentPrioritizationFees(
        lockedWritableAccounts: [
          PublicKey.fromBase58(fromAddress),
          PublicKey.fromBase58(toAddress),
        ],
      );
      final priorityFees = _priorityFeePercentiles(
        recentFees.map((fee) => fee.prioritizationFee),
      );
      return SolanaFeeEstimate(
        lamports: BigInt.from(fee),
        recentBlockhash: blockhash.blockhash,
        computeUnitLimit: computeUnitLimit,
        priorityFeeOptionsMicroLamports: priorityFees,
      );
    } finally {
      await connection.close();
    }
  }
}

Connection _createSolanaConnection(String rpcUrl, Map<String, String> headers) {
  final httpClient = headers.isEmpty
      ? BoundedHttpClient()
      : HeaderHttpClient(headers: headers);
  return Connection(rpcUrl, httpClient: httpClient);
}

List<BigInt> _priorityFeePercentiles(Iterable<int> values) {
  final sorted = values.where((value) => value >= 0).toList()..sort();
  if (sorted.isEmpty) {
    return [BigInt.zero, BigInt.zero, BigInt.zero];
  }
  int percentile(double fraction) {
    final index = ((sorted.length - 1) * fraction).round();
    return sorted[index];
  }

  return [
    BigInt.from(percentile(0.25)),
    BigInt.from(percentile(0.50)),
    BigInt.from(percentile(0.75)),
  ];
}
