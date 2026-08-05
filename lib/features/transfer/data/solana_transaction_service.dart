import 'dart:typed_data';

import 'package:solana_sdk/solana_sdk.dart' as solana;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/header_http_client.dart';
import '../domain/transaction_request.dart';

final class SolanaTransactionBroadcastInput {
  const SolanaTransactionBroadcastInput({
    required this.rpcUrl,
    required this.privateKey,
    required this.fromAddress,
    required this.transaction,
    required this.recentBlockhash,
    this.computeUnitLimit,
    this.microLamportsPerComputeUnit,
    this.headers = const {},
  });

  final String rpcUrl;
  final List<int> privateKey;
  final String fromAddress;
  final TransactionRequest transaction;
  final String? recentBlockhash;
  final int? computeUnitLimit;
  final BigInt? microLamportsPerComputeUnit;
  final Map<String, String> headers;
}

abstract interface class SolanaTransactionService {
  Future<String> signAndBroadcast(SolanaTransactionBroadcastInput input);
}

final class SdkSolanaTransactionService implements SolanaTransactionService {
  const SdkSolanaTransactionService();

  @override
  Future<String> signAndBroadcast(SolanaTransactionBroadcastInput input) async {
    final httpClient = input.headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: input.headers);
    final connection = solana.Connection(input.rpcUrl, httpClient: httpClient);
    try {
      final keypair = solana.Keypair.fromSecretKey(
        Uint8List.fromList(input.privateKey),
      );
      final blockhash = (await connection.getLatestBlockhash()).blockhash;
      final transaction = buildSolanaTransferTransaction(
        fromAddress: input.fromAddress,
        recentBlockhash: blockhash,
        transaction: input.transaction,
        computeUnitLimit: input.computeUnitLimit,
        microLamportsPerComputeUnit: input.microLamportsPerComputeUnit,
      );
      transaction.sign([keypair]);
      return connection.sendRawTransaction(transaction.serialize());
    } finally {
      await connection.close();
    }
  }
}

solana.Transaction buildSolanaTransferTransaction({
  required String fromAddress,
  required String recentBlockhash,
  required TransactionRequest transaction,
  int? computeUnitLimit,
  BigInt? microLamportsPerComputeUnit,
}) {
  final from = solana.PublicKey.fromBase58(fromAddress);
  final result = solana.Transaction(
    feePayer: from,
    recentBlockhash: recentBlockhash,
  );
  if (computeUnitLimit != null &&
      computeUnitLimit > 0 &&
      microLamportsPerComputeUnit != null &&
      microLamportsPerComputeUnit >= BigInt.zero) {
    result
      ..add(
        solana.ComputeBudgetProgram.setComputeUnitLimit(
          units: computeUnitLimit,
        ),
      )
      ..add(
        solana.ComputeBudgetProgram.setComputeUnitPrice(
          microLamports: microLamportsPerComputeUnit,
        ),
      );
  }
  result.add(
    solana.SystemProgram.transfer(
      fromPubkey: from,
      toPubkey: solana.PublicKey.fromBase58(transaction.toAddress),
      lamports: _lamports(transaction),
    ),
  );
  return result;
}

BigInt _lamports(TransactionRequest request) {
  final amount = request.amountInBaseUnits;
  if (amount == null) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must not be null');
  }
  return BigInt.parse(amount);
}
