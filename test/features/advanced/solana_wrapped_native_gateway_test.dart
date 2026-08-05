import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/data/solana_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/wrapped_native_models.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  final owner = solana.Keypair.generate().publicKey;
  final sourceA = solana.Keypair.generate().publicKey;
  final sourceB = solana.Keypair.generate().publicKey;
  final temporary = solana.Keypair.generate().publicKey;
  final blockhash = solana.Keypair.generate().publicKey.toBase58();

  test(
    'wrap creates the WSOL ATA idempotently then transfers and syncs SOL',
    () {
      final transaction = buildSolanaWrapTransaction(
        ownerAddress: owner.toBase58(),
        recentBlockhash: blockhash,
        amountLamports: BigInt.from(1000),
      );

      expect(transaction.instructions, hasLength(3));
      expect(
        transaction.instructions[0].programId,
        solana.AssociatedTokenProgram.programId,
      );
      expect(transaction.instructions[0].data, Uint8List.fromList([1]));
      expect(
        transaction.instructions[1].programId,
        solana.SystemProgram.programId,
      );
      expect(
        transaction.instructions[1].keys[1].pubkey,
        solana.AssociatedTokenProgram.getAssociatedTokenAddress(
          owner: owner,
          mint: solana.PublicKey.fromBase58(wrappedSolMintAddress),
        ),
      );
      expect(
        transaction.instructions[2].programId,
        solana.TokenProgram.token.programId,
      );
      expect(transaction.instructions[2].data.single, 17);
    },
  );

  test('full unwrap closes every selected WSOL account to the wallet', () {
    final transaction = buildSolanaFullUnwrapTransaction(
      ownerAddress: owner.toBase58(),
      recentBlockhash: blockhash,
      accounts: [sourceA.toBase58(), sourceB.toBase58()],
    );

    expect(transaction.instructions, hasLength(2));
    for (final instruction in transaction.instructions) {
      expect(instruction.programId, solana.TokenProgram.token.programId);
      expect(instruction.data.single, 9);
      expect(instruction.keys[1].pubkey, owner);
    }
  });

  test('partial unwrap uses a temporary native account in one transaction', () {
    final transaction = buildSolanaPartialUnwrapTransaction(
      ownerAddress: owner.toBase58(),
      recentBlockhash: blockhash,
      temporaryAccountAddress: temporary.toBase58(),
      temporaryAccountRentLamports: BigInt.from(2039280),
      allocations: [
        SolanaWrappedNativeAllocation(
          sourceAddress: sourceA.toBase58(),
          amountLamports: BigInt.from(600),
        ),
        SolanaWrappedNativeAllocation(
          sourceAddress: sourceB.toBase58(),
          amountLamports: BigInt.from(400),
        ),
      ],
    );

    expect(transaction.instructions, hasLength(5));
    expect(
      transaction.instructions[0].programId,
      solana.SystemProgram.programId,
    );
    expect(transaction.instructions[0].keys[1].pubkey, temporary);
    expect(transaction.instructions[0].keys[1].isSigner, isTrue);
    expect(transaction.instructions[1].data.first, 18);
    expect(transaction.instructions[2].data.first, 3);
    expect(transaction.instructions[3].data.first, 3);
    expect(transaction.instructions[4].data.single, 9);
    expect(transaction.instructions[4].keys[1].pubkey, owner);
  });

  test(
    'allocations consume multiple WSOL accounts without exceeding amount',
    () {
      final allocations = allocateSolanaWrappedNativeSources(
        amountLamports: BigInt.from(1100),
        accounts: [
          SolanaWrappedNativeAccount(
            address: sourceA.toBase58(),
            amountLamports: BigInt.from(600),
            accountLamports: BigInt.from(2039880),
          ),
          SolanaWrappedNativeAccount(
            address: sourceB.toBase58(),
            amountLamports: BigInt.from(900),
            accountLamports: BigInt.from(2040180),
          ),
        ],
      );

      expect(allocations.map((allocation) => allocation.amountLamports), [
        BigInt.from(600),
        BigInt.from(500),
      ]);
    },
  );

  test('prepare wrap includes network fee and ATA rent when missing', () async {
    final connection = _FakeSolanaWrappedNativeConnection(
      solBalanceLamports: BigInt.from(5000000),
      accountExists: false,
      rentLamports: BigInt.from(2039280),
      estimatedFeeLamports: BigInt.from(5000),
      blockhash: blockhash,
    );
    final gateway = DefaultSolanaWrappedNativeGateway(
      connectionFactory: (_, _) => connection,
    );

    final preparation = await gateway.prepare(
      rpcUrl: 'https://solana.example.com',
      ownerAddress: owner.toBase58(),
      operation: WrappedNativeOperation.wrap,
      amountLamports: BigInt.from(1000000),
    );

    expect(preparation.networkFeeLamports, BigInt.from(5000));
    expect(preparation.accountRentLamports, BigInt.from(2039280));
    expect(preparation.requiredSolBalanceLamports, BigInt.from(3044280));
    expect(connection.simulateCalls, 1);
  });

  test('loadBalances keeps connection open until requests finish', () async {
    final loadGate = Completer<void>();
    final connection = _FakeSolanaWrappedNativeConnection(
      solBalanceLamports: BigInt.from(279233179),
      blockhash: blockhash,
      balanceLoadGate: loadGate,
    );
    final gateway = DefaultSolanaWrappedNativeGateway(
      connectionFactory: (_, _) => connection,
    );

    final loadFuture = gateway.loadBalances(
      rpcUrl: 'https://solana.example.com',
      ownerAddress: owner.toBase58(),
    );
    await Future<void>.delayed(Duration.zero);
    final closedBeforeCompletion = connection.isClosed;
    loadGate.complete();

    Object? loadError;
    SolanaWrappedNativeBalances? balances;
    try {
      balances = await loadFuture;
    } catch (error) {
      loadError = error;
    }

    expect(closedBeforeCompletion, isFalse);
    expect(loadError, isNull);
    expect(balances?.solBalanceLamports, BigInt.from(279233179));
    expect(connection.isClosed, isTrue);
  });

  test('prepare partial unwrap allocates sources and temporary rent', () async {
    final connection = _FakeSolanaWrappedNativeConnection(
      solBalanceLamports: BigInt.from(3000000),
      wrappedAccounts: [
        SolanaWrappedNativeAccount(
          address: sourceA.toBase58(),
          amountLamports: BigInt.from(600),
          accountLamports: BigInt.from(2039880),
        ),
        SolanaWrappedNativeAccount(
          address: sourceB.toBase58(),
          amountLamports: BigInt.from(900),
          accountLamports: BigInt.from(2040180),
        ),
      ],
      rentLamports: BigInt.from(2039280),
      estimatedFeeLamports: BigInt.from(5000),
      blockhash: blockhash,
    );
    final gateway = DefaultSolanaWrappedNativeGateway(
      connectionFactory: (_, _) => connection,
    );

    final preparation = await gateway.prepare(
      rpcUrl: 'https://solana.example.com',
      ownerAddress: owner.toBase58(),
      operation: WrappedNativeOperation.unwrap,
      amountLamports: BigInt.from(1100),
    );

    expect(preparation.isFullUnwrap, isFalse);
    expect(preparation.allocations.map((value) => value.amountLamports), [
      BigInt.from(600),
      BigInt.from(500),
    ]);
    expect(preparation.accountRentLamports, BigInt.from(2039280));
    expect(preparation.requiredSolBalanceLamports, BigInt.from(2044280));
  });

  test(
    'partial unwrap submission signs with wallet and temporary account',
    () async {
      final ownerKeypair = solana.Keypair.generate();
      final connection = _FakeSolanaWrappedNativeConnection(
        solBalanceLamports: BigInt.from(3000000),
        wrappedAccounts: [
          SolanaWrappedNativeAccount(
            address: sourceA.toBase58(),
            amountLamports: BigInt.from(1500),
            accountLamports: BigInt.from(2040780),
          ),
        ],
        rentLamports: BigInt.from(2039280),
        estimatedFeeLamports: BigInt.from(5000),
        blockhash: blockhash,
        signature: 'signature',
      );
      final gateway = DefaultSolanaWrappedNativeGateway(
        connectionFactory: (_, _) => connection,
      );
      final preparation = await gateway.prepare(
        rpcUrl: 'https://solana.example.com',
        ownerAddress: ownerKeypair.publicKey.toBase58(),
        operation: WrappedNativeOperation.unwrap,
        amountLamports: BigInt.from(1000),
      );

      final signature = await gateway.submit(
        rpcUrl: 'https://solana.example.com',
        ownerAddress: ownerKeypair.publicKey.toBase58(),
        privateKey: ownerKeypair.secretKey,
        preparation: preparation,
      );

      expect(signature, 'signature');
      expect(connection.sentSignerCounts, [2]);
      expect(connection.confirmedSignatures, ['signature']);
    },
  );
}

final class _FakeSolanaWrappedNativeConnection
    implements SolanaWrappedNativeConnection {
  _FakeSolanaWrappedNativeConnection({
    BigInt? solBalanceLamports,
    this.wrappedAccounts = const [],
    this.accountExists = true,
    BigInt? rentLamports,
    BigInt? estimatedFeeLamports,
    required this.blockhash,
    this.signature = 'signature',
    this.balanceLoadGate,
  }) : solBalanceLamports = solBalanceLamports ?? BigInt.zero,
       rentLamports = rentLamports ?? BigInt.zero,
       estimatedFeeLamports = estimatedFeeLamports ?? BigInt.zero;

  final BigInt solBalanceLamports;
  final List<SolanaWrappedNativeAccount> wrappedAccounts;
  final bool accountExists;
  final BigInt rentLamports;
  final BigInt estimatedFeeLamports;
  final String blockhash;
  final String signature;
  final Completer<void>? balanceLoadGate;

  int simulateCalls = 0;
  bool isClosed = false;
  final sentSignerCounts = <int>[];
  final confirmedSignatures = <String>[];

  @override
  Future<bool> accountExistsAt(solana.PublicKey address) async {
    await _waitForBalanceLoad();
    return accountExists;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<void> confirmSignature(String signature) async {
    confirmedSignatures.add(signature);
  }

  @override
  Future<BigInt> getBalance(solana.PublicKey owner) async {
    await _waitForBalanceLoad();
    return solBalanceLamports;
  }

  @override
  Future<BigInt> getEstimatedFee(solana.Transaction transaction) async {
    return estimatedFeeLamports;
  }

  @override
  Future<String> getLatestBlockhash() async => blockhash;

  @override
  Future<BigInt> getMinimumTokenAccountRent() async => rentLamports;

  @override
  Future<List<SolanaWrappedNativeAccount>> getWrappedNativeAccounts(
    solana.PublicKey owner,
  ) async {
    await _waitForBalanceLoad();
    return wrappedAccounts;
  }

  Future<void> _waitForBalanceLoad() async {
    await balanceLoadGate?.future;
  }

  @override
  Future<String> sendTransaction({
    required solana.Transaction transaction,
    required List<solana.Keypair> signers,
  }) async {
    sentSignerCounts.add(signers.length);
    return signature;
  }

  @override
  Future<void> simulate(solana.Transaction transaction) async {
    simulateCalls += 1;
  }
}
