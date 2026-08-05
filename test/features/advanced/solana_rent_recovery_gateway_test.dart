import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/data/solana_rent_recovery_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/solana_rent_recovery_models.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  test('scan keeps only safe empty SPL and Token-2022 accounts', () async {
    final owner = solana.Keypair.generate().publicKey;
    final wrongAuthority = solana.Keypair.generate().publicKey;
    final splAccount = solana.Keypair.generate().publicKey;
    final token2022Account = solana.Keypair.generate().publicKey;
    final connection = _FakeRentConnection(
      balanceLamports: 100000,
      accountsByProgram: {
        splTokenProgramId: [
          _tokenAccount(
            address: splAccount,
            owner: owner,
            programId: splTokenProgramId,
            lamports: 2039280,
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: owner,
            programId: splTokenProgramId,
            amount: '1',
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: owner,
            programId: splTokenProgramId,
            isNative: true,
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: owner,
            programId: splTokenProgramId,
            closeAuthority: wrongAuthority,
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: wrongAuthority,
            programId: splTokenProgramId,
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: owner,
            programId: token2022ProgramId,
          ),
        ],
        token2022ProgramId: [
          _tokenAccount(
            address: token2022Account,
            owner: owner,
            programId: token2022ProgramId,
            lamports: 2500000,
          ),
          _tokenAccount(
            address: solana.Keypair.generate().publicKey,
            owner: owner,
            programId: token2022ProgramId,
            withheldAmount: '3',
          ),
        ],
      },
    );
    final gateway = SdkSolanaRentRecoveryGateway(
      connectionFactory: (_) => connection,
    );

    final result = await gateway.scan(
      rpcUrl: 'https://solana.example',
      ownerAddress: owner.toBase58(),
    );

    expect(
      result.accounts.map((account) => account.address).toSet(),
      {splAccount.toBase58(), token2022Account.toBase58()},
    );
    expect(result.totalRecoverableLamports, BigInt.from(4539280));
    expect(result.solBalanceLamports, BigInt.from(100000));
    expect(connection.closed, isTrue);
  });

  test('estimate batches accounts and sums network fees', () async {
    final owner = solana.Keypair.generate().publicKey;
    final accounts = List.generate(
      41,
      (index) => SolanaRentAccount(
        address: solana.Keypair.generate().publicKey.toBase58(),
        mintAddress: solana.Keypair.generate().publicKey.toBase58(),
        program: index.isEven
            ? SolanaRentTokenProgram.splToken
            : SolanaRentTokenProgram.token2022,
        recoverableLamports: BigInt.from(2039280),
      ),
    );
    final connection = _FakeRentConnection(
      balanceLamports: 100000,
      estimatedFeeLamports: 5000,
    );
    final gateway = SdkSolanaRentRecoveryGateway(
      connectionFactory: (_) => connection,
    );

    final estimate = await gateway.estimate(
      rpcUrl: 'https://solana.example',
      ownerAddress: owner.toBase58(),
      accounts: accounts,
    );

    expect(estimate.batches, hasLength(3));
    expect(
      estimate.batches.every((batch) => batch.accounts.length <= 20),
      isTrue,
    );
    expect(estimate.networkFeeLamports, BigInt.from(15000));
    expect(
      estimate.netRecoverableLamports,
      accounts.fold(BigInt.zero,
              (sum, account) => sum + account.recoverableLamports) -
          BigInt.from(15000),
    );
    expect(connection.simulatedTransactions, hasLength(3));
  });

  test('estimate requests the fee with confirmed commitment', () async {
    final feeCommitments = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      final method = body['method'] as String;
      final params = body['params'] as List<dynamic>? ?? const [];
      final result = switch (method) {
        'getLatestBlockhash' => {
          'context': {'slot': 99},
          'value': {
            'blockhash': 'CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8',
            'lastValidBlockHeight': 123456,
          },
        },
        'simulateTransaction' => {
          'context': {'slot': 100},
          'value': {
            'err': null,
            'logs': <String>[],
            'accounts': null,
            'unitsConsumed': 10000,
          },
        },
        'getFeeForMessage' => () {
          final config = params.length > 1
              ? params[1] as Map<String, dynamic>
              : const <String, dynamic>{};
          final commitment = config['commitment'] as String?;
          feeCommitments.add(commitment);
          return {
            'context': {'slot': 101},
            'value': commitment == 'confirmed' ? 5000 : null,
          };
        }(),
        'getBalance' => {
          'context': {'slot': 102},
          'value': 100000,
        },
        _ => throw StateError('Unexpected RPC method $method'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      );
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final owner = solana.Keypair.generate().publicKey;
    final gateway = const SdkSolanaRentRecoveryGateway();

    final estimate = await gateway.estimate(
      rpcUrl: 'http://${server.address.address}:${server.port}',
      ownerAddress: owner.toBase58(),
      accounts: [
        SolanaRentAccount(
          address: solana.Keypair.generate().publicKey.toBase58(),
          mintAddress: solana.Keypair.generate().publicKey.toBase58(),
          program: SolanaRentTokenProgram.splToken,
          recoverableLamports: BigInt.from(2039280),
        ),
      ],
    );

    expect(estimate.networkFeeLamports, BigInt.from(5000));
    expect(feeCommitments, ['confirmed']);
  });

  test('recover signs, broadcasts, and confirms every batch', () async {
    final keypair = solana.Keypair.generate();
    final accounts = List.generate(
      2,
      (index) => SolanaRentAccount(
        address: solana.Keypair.generate().publicKey.toBase58(),
        mintAddress: solana.Keypair.generate().publicKey.toBase58(),
        program: SolanaRentTokenProgram.splToken,
        recoverableLamports: BigInt.from(2039280),
      ),
    );
    final connection = _FakeRentConnection(
      balanceLamports: 100000,
      sentSignatures: ['signature-a'],
    );
    final gateway = SdkSolanaRentRecoveryGateway(
      connectionFactory: (_) => connection,
    );

    final result = await gateway.recover(
      rpcUrl: 'https://solana.example',
      ownerAddress: keypair.publicKey.toBase58(),
      privateKey: keypair.secretKey,
      batches: [SolanaRentRecoveryBatch(accounts: accounts)],
    );

    expect(result.signatures, ['signature-a']);
    expect(result.completedAccountCount, 2);
    expect(result.recoveredLamports, BigInt.from(4078560));
    expect(connection.serializedTransactions.single, isNotEmpty);
    expect(connection.confirmedSignatures, ['signature-a']);
  });

  test('recover broadcasts with confirmed preflight commitment', () async {
    final preflightCommitments = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      final method = body['method'] as String;
      final params = body['params'] as List<dynamic>? ?? const [];
      final result = switch (method) {
        'getLatestBlockhash' => {
          'context': {'slot': 99},
          'value': {
            'blockhash': 'CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8',
            'lastValidBlockHeight': 123456,
          },
        },
        'simulateTransaction' => {
          'context': {'slot': 100},
          'value': {
            'err': null,
            'logs': <String>[],
            'accounts': null,
            'unitsConsumed': 10000,
          },
        },
        'sendTransaction' => () {
          final config = params[1] as Map<String, dynamic>;
          preflightCommitments.add(config['preflightCommitment'] as String?);
          return 'signature-a';
        }(),
        'getSignatureStatuses' => {
          'context': {'slot': 102},
          'value': [
            {
              'slot': 101,
              'confirmations': 1,
              'err': null,
              'confirmationStatus': 'confirmed',
            },
          ],
        },
        _ => throw StateError('Unexpected RPC method $method'),
      };
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'jsonrpc': '2.0', 'id': body['id'], 'result': result}),
      );
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final keypair = solana.Keypair.generate();
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final gateway = const SdkSolanaRentRecoveryGateway();

    final result = await gateway.recover(
      rpcUrl: 'http://${server.address.address}:${server.port}',
      ownerAddress: keypair.publicKey.toBase58(),
      privateKey: keypair.secretKey,
      batches: [SolanaRentRecoveryBatch(accounts: [account])],
    );

    expect(result.isSuccess, isTrue);
    expect(preflightCommitments, ['confirmed']);
  });

  test('a full mixed-program batch stays within Solana transaction size',
      () async {
    final keypair = solana.Keypair.generate();
    final accounts = List.generate(
      SdkSolanaRentRecoveryGateway.maxAccountsPerBatch,
      (index) => SolanaRentAccount(
        address: solana.Keypair.generate().publicKey.toBase58(),
        mintAddress: solana.Keypair.generate().publicKey.toBase58(),
        program: index.isEven
            ? SolanaRentTokenProgram.splToken
            : SolanaRentTokenProgram.token2022,
        recoverableLamports: BigInt.from(2039280),
      ),
    );
    final transaction = buildSolanaRentRecoveryTransaction(
      ownerAddress: keypair.publicKey.toBase58(),
      recentBlockhash: '11111111111111111111111111111111',
      accounts: accounts,
    )..sign([keypair]);

    expect(transaction.serialize().length, lessThanOrEqualTo(1232));
  });

  test('recover returns completed batches when a later batch fails', () async {
    final keypair = solana.Keypair.generate();
    final firstAccount = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final secondAccount = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.token2022,
      recoverableLamports: BigInt.from(2500000),
    );
    final connection = _FakeRentConnection(
      balanceLamports: 100000,
      sentSignatures: ['signature-a'],
    );
    final gateway = SdkSolanaRentRecoveryGateway(
      connectionFactory: (_) => connection,
    );

    final result = await gateway.recover(
      rpcUrl: 'https://solana.example',
      ownerAddress: keypair.publicKey.toBase58(),
      privateKey: keypair.secretKey,
      batches: [
        SolanaRentRecoveryBatch(accounts: [firstAccount]),
        SolanaRentRecoveryBatch(accounts: [secondAccount]),
      ],
    );

    expect(result.isPartial, isTrue);
    expect(result.signatures, ['signature-a']);
    expect(result.completedAccountCount, 1);
    expect(result.recoveredLamports, firstAccount.recoverableLamports);
  });

  test('recover closes the RPC connection when the private key is invalid',
      () async {
    final owner = solana.Keypair.generate().publicKey;
    final connection = _FakeRentConnection(balanceLamports: 100000);
    final gateway = SdkSolanaRentRecoveryGateway(
      connectionFactory: (_) => connection,
    );

    await expectLater(
      gateway.recover(
        rpcUrl: 'https://solana.example',
        ownerAddress: owner.toBase58(),
        privateKey: const [1, 2, 3],
        batches: const [],
      ),
      throwsA(anything),
    );

    expect(connection.closed, isTrue);
  });
}

solana.TokenAccountInfo _tokenAccount({
  required solana.PublicKey address,
  required solana.PublicKey owner,
  required String programId,
  int lamports = 2039280,
  String amount = '0',
  bool isNative = false,
  solana.PublicKey? closeAuthority,
  String? withheldAmount,
}) {
  return solana.TokenAccountInfo(
    pubkey: address,
    account: solana.AccountInfo<Map<String, Object?>>(
      lamports: lamports,
      owner: solana.PublicKey.fromBase58(programId),
      executable: false,
      rentEpoch: 0,
      space: programId == token2022ProgramId ? 182 : 165,
      data: {
        'program': 'spl-token',
        'parsed': {
          'type': 'account',
          'info': {
            'mint': solana.Keypair.generate().publicKey.toBase58(),
            'owner': owner.toBase58(),
            'tokenAmount': {'amount': amount, 'decimals': 6},
            'isNative': isNative,
            if (closeAuthority != null)
              'closeAuthority': closeAuthority.toBase58(),
            if (withheldAmount != null)
              'extensions': [
                {
                  'extension': 'transferFeeAmount',
                  'state': {'withheldAmount': withheldAmount},
                },
              ],
          },
        },
      },
    ),
  );
}

final class _FakeRentConnection implements SolanaRentRecoveryConnection {
  _FakeRentConnection({
    required this.balanceLamports,
    this.accountsByProgram = const {},
    this.estimatedFeeLamports = 5000,
    List<String>? sentSignatures,
  }) : _sentSignatures = sentSignatures ?? [];

  final int balanceLamports;
  final Map<String, List<solana.TokenAccountInfo>> accountsByProgram;
  final int estimatedFeeLamports;
  final List<String> _sentSignatures;
  final List<solana.Transaction> simulatedTransactions = [];
  final List<Uint8List> serializedTransactions = [];
  final List<String> confirmedSignatures = [];
  bool closed = false;

  @override
  Future<List<solana.TokenAccountInfo>> getTokenAccountsByOwner({
    required solana.PublicKey owner,
    required String programId,
  }) async {
    return accountsByProgram[programId] ?? const [];
  }

  @override
  Future<int> getBalance(solana.PublicKey owner) async => balanceLamports;

  @override
  Future<String> getLatestBlockhash() async =>
      '11111111111111111111111111111111';

  @override
  Future<int?> getEstimatedFee(solana.Transaction transaction) async {
    return estimatedFeeLamports;
  }

  @override
  Future<Object?> simulate(solana.Transaction transaction) async {
    simulatedTransactions.add(transaction);
    return null;
  }

  @override
  Future<String> sendRawTransaction(Uint8List transaction) async {
    serializedTransactions.add(transaction);
    return _sentSignatures.removeAt(0);
  }

  @override
  Future<void> confirmSignature(String signature) async {
    confirmedSignatures.add(signature);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
