import 'dart:typed_data';

import 'package:solana_sdk/solana_sdk.dart' as solana;

import '../domain/solana_rent_recovery_models.dart';

const splTokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
const token2022ProgramId = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';

typedef SolanaRentRecoveryConnectionFactory = SolanaRentRecoveryConnection
    Function(String rpcUrl);

abstract interface class SolanaRentRecoveryConnection {
  Future<List<solana.TokenAccountInfo>> getTokenAccountsByOwner({
    required solana.PublicKey owner,
    required String programId,
  });

  Future<int> getBalance(solana.PublicKey owner);

  Future<String> getLatestBlockhash();

  Future<int?> getEstimatedFee(solana.Transaction transaction);

  Future<Object?> simulate(solana.Transaction transaction);

  Future<String> sendRawTransaction(Uint8List transaction);

  Future<void> confirmSignature(String signature);

  Future<void> close();
}

abstract interface class SolanaRentRecoveryGateway {
  Future<SolanaRentScanResult> scan({
    required String rpcUrl,
    required String ownerAddress,
  });

  Future<SolanaRentRecoveryEstimate> estimate({
    required String rpcUrl,
    required String ownerAddress,
    required List<SolanaRentAccount> accounts,
  });

  Future<SolanaRentRecoveryResult> recover({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required List<SolanaRentRecoveryBatch> batches,
  });
}

final class SdkSolanaRentRecoveryGateway implements SolanaRentRecoveryGateway {
  const SdkSolanaRentRecoveryGateway({this.connectionFactory});

  static const int maxAccountsPerBatch = 20;

  final SolanaRentRecoveryConnectionFactory? connectionFactory;

  @override
  Future<SolanaRentScanResult> scan({
    required String rpcUrl,
    required String ownerAddress,
  }) async {
    final connection = _connection(rpcUrl);
    final owner = solana.PublicKey.fromBase58(ownerAddress);
    try {
      final responses = await Future.wait([
        connection.getTokenAccountsByOwner(
          owner: owner,
          programId: splTokenProgramId,
        ),
        connection.getTokenAccountsByOwner(
          owner: owner,
          programId: token2022ProgramId,
        ),
      ]);
      final accounts = <SolanaRentAccount>[
        ..._eligibleAccounts(
          responses[0],
          owner: ownerAddress,
          program: SolanaRentTokenProgram.splToken,
        ),
        ..._eligibleAccounts(
          responses[1],
          owner: ownerAddress,
          program: SolanaRentTokenProgram.token2022,
        ),
      ]..sort((left, right) => right.recoverableLamports.compareTo(
            left.recoverableLamports,
          ));
      return SolanaRentScanResult(
        accounts: accounts,
        solBalanceLamports: BigInt.from(await connection.getBalance(owner)),
      );
    } finally {
      await connection.close();
    }
  }

  @override
  Future<SolanaRentRecoveryEstimate> estimate({
    required String rpcUrl,
    required String ownerAddress,
    required List<SolanaRentAccount> accounts,
  }) async {
    final connection = _connection(rpcUrl);
    final owner = solana.PublicKey.fromBase58(ownerAddress);
    try {
      final blockhash = await connection.getLatestBlockhash();
      final batches = <SolanaRentRecoveryBatch>[];
      for (var offset = 0;
          offset < accounts.length;
          offset += maxAccountsPerBatch) {
        final end = (offset + maxAccountsPerBatch).clamp(0, accounts.length);
        final batchAccounts = accounts.sublist(offset, end);
        final transaction = buildSolanaRentRecoveryTransaction(
          ownerAddress: ownerAddress,
          recentBlockhash: blockhash,
          accounts: batchAccounts,
        );
        final simulationError = await connection.simulate(transaction);
        if (simulationError != null) {
          throw StateError('solana_rent_recovery_simulation_failed');
        }
        final fee = await connection.getEstimatedFee(transaction);
        if (fee == null) {
          throw StateError('solana_rent_recovery_fee_unavailable');
        }
        batches.add(
          SolanaRentRecoveryBatch(
            accounts: batchAccounts,
            estimatedFeeLamports: BigInt.from(fee),
          ),
        );
      }
      if (accounts.isNotEmpty) {
        await connection.getBalance(owner);
      }
      return SolanaRentRecoveryEstimate(batches: batches);
    } finally {
      await connection.close();
    }
  }

  @override
  Future<SolanaRentRecoveryResult> recover({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required List<SolanaRentRecoveryBatch> batches,
  }) async {
    final connection = _connection(rpcUrl);
    try {
      final keypair = solana.Keypair.fromSecretKey(
        Uint8List.fromList(privateKey),
      );
      if (keypair.publicKey.toBase58() != ownerAddress) {
        throw StateError('solana_rent_recovery_signer_mismatch');
      }
      final signatures = <String>[];
      var completedAccountCount = 0;
      var recoveredLamports = BigInt.zero;
      String? errorMessage;
      for (final batch in batches) {
        try {
          final transaction = buildSolanaRentRecoveryTransaction(
            ownerAddress: ownerAddress,
            recentBlockhash: await connection.getLatestBlockhash(),
            accounts: batch.accounts,
          );
          final simulationError = await connection.simulate(transaction);
          if (simulationError != null) {
            throw StateError('solana_rent_recovery_simulation_failed');
          }
          transaction.sign([keypair]);
          final signature = await connection.sendRawTransaction(
            transaction.serialize(),
          );
          await connection.confirmSignature(signature);
          signatures.add(signature);
          completedAccountCount += batch.accounts.length;
          recoveredLamports += batch.accounts.fold(
            BigInt.zero,
            (sum, account) => sum + account.recoverableLamports,
          );
        } catch (error) {
          errorMessage = error.toString();
          break;
        }
      }
      return SolanaRentRecoveryResult(
        signatures: signatures,
        completedAccountCount: completedAccountCount,
        recoveredLamports: recoveredLamports,
        errorMessage: errorMessage,
      );
    } finally {
      await connection.close();
    }
  }

  SolanaRentRecoveryConnection _connection(String rpcUrl) {
    return (connectionFactory ?? _sdkConnection)(rpcUrl);
  }
}

solana.Transaction buildSolanaRentRecoveryTransaction({
  required String ownerAddress,
  required String recentBlockhash,
  required List<SolanaRentAccount> accounts,
}) {
  final owner = solana.PublicKey.fromBase58(ownerAddress);
  final transaction = solana.Transaction(
    feePayer: owner,
    recentBlockhash: recentBlockhash,
  );
  for (final account in accounts) {
    final program = switch (account.program) {
      SolanaRentTokenProgram.splToken => solana.TokenProgram.token,
      SolanaRentTokenProgram.token2022 => solana.TokenProgram.token2022,
    };
    transaction.add(
      program.closeAccount(
        account: solana.PublicKey.fromBase58(account.address),
        destination: owner,
        owner: owner,
      ),
    );
  }
  return transaction;
}

List<SolanaRentAccount> _eligibleAccounts(
  List<solana.TokenAccountInfo> accounts, {
  required String owner,
  required SolanaRentTokenProgram program,
}) {
  return accounts
      .map((account) =>
          _eligibleAccount(account, owner: owner, program: program))
      .whereType<SolanaRentAccount>()
      .toList(growable: false);
}

SolanaRentAccount? _eligibleAccount(
  solana.TokenAccountInfo account, {
  required String owner,
  required SolanaRentTokenProgram program,
}) {
  final expectedProgramId = switch (program) {
    SolanaRentTokenProgram.splToken => splTokenProgramId,
    SolanaRentTokenProgram.token2022 => token2022ProgramId,
  };
  if (account.account.owner.toBase58() != expectedProgramId ||
      account.account.executable ||
      account.account.lamports <= 0) {
    return null;
  }
  final data = account.account.data;
  if (data is! Map) {
    return null;
  }
  final parsed = data['parsed'];
  if (parsed is! Map || parsed['type'] != 'account') {
    return null;
  }
  final info = parsed['info'];
  if (info is! Map || info['owner'] != owner) {
    return null;
  }
  final tokenAmount = info['tokenAmount'];
  if (tokenAmount is! Map || tokenAmount['amount'] != '0') {
    return null;
  }
  if (info['isNative'] == true) {
    return null;
  }
  final closeAuthority = info['closeAuthority'];
  if (closeAuthority != null && closeAuthority != owner) {
    return null;
  }
  if (_containsPositiveWithheldAmount(info)) {
    return null;
  }
  final mint = info['mint'];
  if (mint is! String || mint.isEmpty) {
    return null;
  }
  return SolanaRentAccount(
    address: account.pubkey.toBase58(),
    mintAddress: mint,
    program: program,
    recoverableLamports: BigInt.from(account.account.lamports),
  );
}

bool _containsPositiveWithheldAmount(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key == 'withheldAmount') {
        final amount = BigInt.tryParse(entry.value.toString());
        if (amount != null && amount > BigInt.zero) {
          return true;
        }
      }
      if (_containsPositiveWithheldAmount(entry.value)) {
        return true;
      }
    }
  } else if (value is List) {
    return value.any(_containsPositiveWithheldAmount);
  }
  return false;
}

SolanaRentRecoveryConnection _sdkConnection(String rpcUrl) {
  return _SdkSolanaRentRecoveryConnection(solana.Connection(rpcUrl));
}

final class _SdkSolanaRentRecoveryConnection
    implements SolanaRentRecoveryConnection {
  const _SdkSolanaRentRecoveryConnection(this._connection);

  final solana.Connection _connection;

  @override
  Future<List<solana.TokenAccountInfo>> getTokenAccountsByOwner({
    required solana.PublicKey owner,
    required String programId,
  }) async {
    final response = await _connection.getParsedTokenAccountsByOwner(
      owner,
      filter: solana.TokenAccountsFilter.programId(programId),
      commitment: solana.Commitment.confirmed,
    );
    return response.value;
  }

  @override
  Future<int> getBalance(solana.PublicKey owner) {
    return _connection.getBalance(owner,
        commitment: solana.Commitment.confirmed);
  }

  @override
  Future<String> getLatestBlockhash() async {
    return (await _connection.getLatestBlockhash(
      commitment: solana.Commitment.confirmed,
    ))
        .blockhash;
  }

  @override
  Future<int?> getEstimatedFee(solana.Transaction transaction) async {
    final response = await _connection.getFeeForMessage(
      transaction.compileMessage(),
      commitment: solana.Commitment.confirmed,
    );
    return response.value;
  }

  @override
  Future<Object?> simulate(solana.Transaction transaction) async {
    final response = await _connection.simulateTransaction(
      transaction,
      sigVerify: false,
      replaceRecentBlockhash: true,
      commitment: solana.Commitment.confirmed,
    );
    return response.value.err;
  }

  @override
  Future<String> sendRawTransaction(Uint8List transaction) {
    return _connection.sendRawTransaction(
      transaction,
      options: solana.SendOptions(
        preflightCommitment: solana.Commitment.confirmed,
      ),
    );
  }

  @override
  Future<void> confirmSignature(String signature) async {
    await _connection.confirmSignature(
      signature,
      commitment: solana.Commitment.confirmed,
    );
  }

  @override
  Future<void> close() => _connection.close();
}
