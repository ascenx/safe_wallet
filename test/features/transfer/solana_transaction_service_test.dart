import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/data/solana_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  test(
    'Solana fee quote covers compute-budget instructions in broadcast',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final methods = <String>[];
      const blockhash = 'CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8';
      const signature = 'test-solana-transaction-signature';
      server.listen((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        final method = body['method'] as String;
        methods.add(method);
        Object? result;
        Object? error;
        switch (method) {
          case 'getLatestBlockhash':
            result = {
              'context': {'slot': 99},
              'value': {'blockhash': blockhash, 'lastValidBlockHeight': 123456},
            };
          case 'sendTransaction':
            final transaction = solana.Transaction.from(
              base64Decode((body['params'] as List).first as String),
            );
            final limit = solana.ComputeBudgetProgram.decodeSetComputeUnitLimit(
              transaction.instructions.first,
            ).units;
            // Both the system transfer and each compute-budget instruction
            // consume 150 CU in the Solana runtime.
            if (limit < transaction.instructions.length * 150) {
              error = {
                'code': -32002,
                'message': 'Transaction simulation failed',
                'data': {
                  'err': {
                    'InstructionError': [
                      limit ~/ 150,
                      'ComputationalBudgetExceeded',
                    ],
                  },
                },
              };
            } else {
              expect(transaction.verifySignatures(), isTrue);
              result = signature;
            }
          case 'getFeeForMessage':
            result = {
              'context': {'slot': 99},
              'value': 5000,
            };
          case 'simulateTransaction':
            final transaction = solana.Transaction.from(
              base64Decode((body['params'] as List).first as String),
            );
            result = {
              'context': {'slot': 99},
              'value': {
                'err': null,
                'logs': <String>[],
                'unitsConsumed': transaction.instructions.length * 150,
              },
            };
          case 'getRecentPrioritizationFees':
            result = [
              {'slot': 99, 'prioritizationFee': 0},
            ];
          default:
            throw StateError('Unexpected RPC method $method');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': body['id'],
            if (error != null) 'error': error else 'result': result,
          }),
        );
        await request.response.close();
      });
      final keypair = solana.Keypair.fromSeed(
        Uint8List.fromList(List.filled(32, 7)),
      );
      final rpcUrl = 'http://127.0.0.1:${server.port}';
      final estimate = await const SdkSolanaFeeService().estimateSolTransferFee(
        rpcUrl: rpcUrl,
        fromAddress: keypair.publicKey.toBase58(),
        toAddress: 'So11111111111111111111111111111111111111112',
        lamports: BigInt.from(100000000),
      );

      final broadcast = const SdkSolanaTransactionService().signAndBroadcast(
        SolanaTransactionBroadcastInput(
          rpcUrl: rpcUrl,
          privateKey: keypair.secretKey,
          fromAddress: keypair.publicKey.toBase58(),
          transaction: const TransactionRequest(
            chainId: 'mainnet-beta',
            chainType: ChainType.solana,
            assetSymbol: 'SOL',
            toAddress: 'So11111111111111111111111111111111111111112',
            amount: '0.1',
            amountInBaseUnits: '100000000',
            tokenDecimals: 9,
            transactionType: TransactionType.solTransfer,
          ),
          recentBlockhash: null,
          computeUnitLimit: estimate.computeUnitLimit,
          microLamportsPerComputeUnit:
              estimate.priorityFeeOptionsMicroLamports[1],
        ),
      );

      await expectLater(broadcast, completion(signature));
      expect(estimate.computeUnitLimit, 495);
      expect(methods, [
        'getLatestBlockhash',
        'getFeeForMessage',
        'simulateTransaction',
        'getRecentPrioritizationFees',
        'getLatestBlockhash',
        'sendTransaction',
      ]);
    },
  );

  test(
    'Solana transfer transaction prepends CU limit and price instructions',
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
    },
  );
}
