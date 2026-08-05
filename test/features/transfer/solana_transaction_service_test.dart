import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/data/solana_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  test('Solana transfer transaction prepends CU limit and price instructions',
      () {
    final transaction = buildSolanaTransferTransaction(
      fromAddress: '11111111111111111111111111111111',
      recentBlockhash: '11111111111111111111111111111111',
      transaction: const TransactionRequest(
        chainId: 'solana-mainnet',
        chainType: ChainType.solana,
        assetSymbol: 'SOL',
        toAddress: 'So11111111111111111111111111111111111111112',
        amount: '0.1',
        amountInBaseUnits: '100000000',
        tokenDecimals: 9,
        transactionType: TransactionType.solTransfer,
      ),
      computeUnitLimit: 220000,
      microLamportsPerComputeUnit: BigInt.from(2000),
    );

    expect(transaction.instructions, hasLength(3));
    expect(
      transaction.instructions[0].programId,
      solana.ComputeBudgetProgram.programId,
    );
    expect(
      solana.ComputeBudgetProgram.decodeSetComputeUnitLimit(
        transaction.instructions[0],
      ).units,
      220000,
    );
    expect(
      solana.ComputeBudgetProgram.decodeSetComputeUnitPrice(
        transaction.instructions[1],
      ).microLamports,
      BigInt.from(2000),
    );
    expect(
      transaction.instructions[2].programId,
      solana.SystemProgram.programId,
    );
  });
}
