import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:solana_sdk/solana_sdk.dart' as solana;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/header_http_client.dart';
import '../domain/wrapped_native_models.dart';

const solanaTokenAccountSize = 165;

final class SolanaWrappedNativeAccount {
  const SolanaWrappedNativeAccount({
    required this.address,
    required this.amountLamports,
    required this.accountLamports,
  });

  final String address;
  final BigInt amountLamports;
  final BigInt accountLamports;
}

final class SolanaWrappedNativeAllocation {
  const SolanaWrappedNativeAllocation({
    required this.sourceAddress,
    required this.amountLamports,
  });

  final String sourceAddress;
  final BigInt amountLamports;
}

final class SolanaWrappedNativeBalances {
  SolanaWrappedNativeBalances({
    required this.solBalanceLamports,
    required List<SolanaWrappedNativeAccount> wrappedAccounts,
    required this.associatedTokenAccountExists,
  }) : wrappedAccounts = List.unmodifiable(wrappedAccounts);

  final BigInt solBalanceLamports;
  final List<SolanaWrappedNativeAccount> wrappedAccounts;
  final bool associatedTokenAccountExists;

  BigInt get wrappedBalanceLamports => wrappedAccounts.fold(
    BigInt.zero,
    (sum, account) => sum + account.amountLamports,
  );
}

final class SolanaWrappedNativePreparation {
  SolanaWrappedNativePreparation({
    required this.operation,
    required this.amountLamports,
    required this.networkFeeLamports,
    required this.accountRentLamports,
    required this.solBalanceLamports,
    required this.wrappedBalanceLamports,
    required this.associatedTokenAccountExists,
    required this.isFullUnwrap,
    List<SolanaWrappedNativeAccount> accounts = const [],
    List<SolanaWrappedNativeAllocation> allocations = const [],
    List<int>? temporaryPrivateKey,
  }) : accounts = List.unmodifiable(accounts),
       allocations = List.unmodifiable(allocations),
       temporaryPrivateKey = temporaryPrivateKey == null
           ? null
           : List.unmodifiable(temporaryPrivateKey);

  final WrappedNativeOperation operation;
  final BigInt amountLamports;
  final BigInt networkFeeLamports;
  final BigInt accountRentLamports;
  final BigInt solBalanceLamports;
  final BigInt wrappedBalanceLamports;
  final bool associatedTokenAccountExists;
  final bool isFullUnwrap;
  final List<SolanaWrappedNativeAccount> accounts;
  final List<SolanaWrappedNativeAllocation> allocations;
  final List<int>? temporaryPrivateKey;

  BigInt get requiredSolBalanceLamports => switch (operation) {
    WrappedNativeOperation.wrap =>
      amountLamports + networkFeeLamports + accountRentLamports,
    WrappedNativeOperation.unwrap => networkFeeLamports + accountRentLamports,
  };
}

typedef SolanaWrappedNativeConnectionFactory =
    SolanaWrappedNativeConnection Function(
      String rpcUrl,
      Map<String, String> headers,
    );

abstract interface class SolanaWrappedNativeConnection {
  Future<BigInt> getBalance(solana.PublicKey owner);

  Future<List<SolanaWrappedNativeAccount>> getWrappedNativeAccounts(
    solana.PublicKey owner,
  );

  Future<bool> accountExistsAt(solana.PublicKey address);

  Future<BigInt> getMinimumTokenAccountRent();

  Future<String> getLatestBlockhash();

  Future<BigInt> getEstimatedFee(solana.Transaction transaction);

  Future<void> simulate(solana.Transaction transaction);

  Future<String> sendTransaction({
    required solana.Transaction transaction,
    required List<solana.Keypair> signers,
  });

  Future<void> confirmSignature(String signature);

  Future<void> close();
}

abstract interface class SolanaWrappedNativeGateway {
  Future<SolanaWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  });

  Future<SolanaWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String ownerAddress,
    required WrappedNativeOperation operation,
    required BigInt amountLamports,
    Map<String, String> headers = const {},
  });

  Future<String> submit({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required SolanaWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  });
}

final class DefaultSolanaWrappedNativeGateway
    implements SolanaWrappedNativeGateway {
  const DefaultSolanaWrappedNativeGateway({this.connectionFactory});

  final SolanaWrappedNativeConnectionFactory? connectionFactory;

  @override
  Future<SolanaWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  }) async {
    final connection = _connection(rpcUrl, headers);
    try {
      return await _load(connection, ownerAddress);
    } finally {
      await connection.close();
    }
  }

  @override
  Future<SolanaWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String ownerAddress,
    required WrappedNativeOperation operation,
    required BigInt amountLamports,
    Map<String, String> headers = const {},
  }) async {
    if (amountLamports <= BigInt.zero) {
      throw ArgumentError.value(amountLamports, 'amountLamports');
    }
    final connection = _connection(rpcUrl, headers);
    try {
      final balances = await _load(connection, ownerAddress);
      final blockhash = await connection.getLatestBlockhash();
      final rent = await connection.getMinimumTokenAccountRent();
      final plan = _buildPlan(
        balances: balances,
        ownerAddress: ownerAddress,
        blockhash: blockhash,
        operation: operation,
        amountLamports: amountLamports,
        rentLamports: rent,
      );
      await connection.simulate(plan.transaction);
      final fee = await connection.getEstimatedFee(plan.transaction);
      final preparation = SolanaWrappedNativePreparation(
        operation: operation,
        amountLamports: amountLamports,
        networkFeeLamports: fee,
        accountRentLamports: plan.accountRentLamports,
        solBalanceLamports: balances.solBalanceLamports,
        wrappedBalanceLamports: balances.wrappedBalanceLamports,
        associatedTokenAccountExists: balances.associatedTokenAccountExists,
        isFullUnwrap: plan.isFullUnwrap,
        accounts: plan.accounts,
        allocations: plan.allocations,
        temporaryPrivateKey: plan.temporaryKeypair?.secretKey,
      );
      if (balances.solBalanceLamports <
          preparation.requiredSolBalanceLamports) {
        throw StateError('insufficient_sol_balance');
      }
      return preparation;
    } finally {
      await connection.close();
    }
  }

  @override
  Future<String> submit({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required SolanaWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    final connection = _connection(rpcUrl, headers);
    try {
      final walletKeypair = solana.Keypair.fromSecretKey(
        Uint8List.fromList(privateKey),
      );
      if (walletKeypair.publicKey.toBase58() != ownerAddress) {
        throw StateError('wrapped_native_signer_mismatch');
      }
      final balances = await _load(connection, ownerAddress);
      _validateFreshBalances(preparation, balances);
      final blockhash = await connection.getLatestBlockhash();
      final temporaryKeypair = preparation.temporaryPrivateKey == null
          ? null
          : solana.Keypair.fromSecretKey(
              Uint8List.fromList(preparation.temporaryPrivateKey!),
            );
      final transaction = _rebuildTransaction(
        ownerAddress: ownerAddress,
        blockhash: blockhash,
        preparation: preparation,
        temporaryKeypair: temporaryKeypair,
      );
      await connection.simulate(transaction);
      final fee = await connection.getEstimatedFee(transaction);
      final ataRent =
          preparation.operation == WrappedNativeOperation.wrap &&
              !balances.associatedTokenAccountExists
          ? preparation.accountRentLamports
          : BigInt.zero;
      final requiredSol =
          fee +
          ataRent +
          (preparation.operation == WrappedNativeOperation.wrap
              ? preparation.amountLamports
              : preparation.isFullUnwrap
              ? BigInt.zero
              : preparation.accountRentLamports);
      if (balances.solBalanceLamports < requiredSol) {
        throw StateError('insufficient_sol_balance');
      }
      final signature = await connection.sendTransaction(
        transaction: transaction,
        signers: [walletKeypair, ?temporaryKeypair],
      );
      await connection.confirmSignature(signature);
      return signature;
    } finally {
      await connection.close();
    }
  }

  Future<SolanaWrappedNativeBalances> _load(
    SolanaWrappedNativeConnection connection,
    String ownerAddress,
  ) async {
    final owner = solana.PublicKey.fromBase58(ownerAddress);
    final ata = solana.AssociatedTokenProgram.getAssociatedTokenAddress(
      owner: owner,
      mint: solana.PublicKey.fromBase58(wrappedSolMintAddress),
    );
    final values = await Future.wait<Object>([
      connection.getBalance(owner),
      connection.getWrappedNativeAccounts(owner),
      connection.accountExistsAt(ata),
    ]);
    return SolanaWrappedNativeBalances(
      solBalanceLamports: values[0] as BigInt,
      wrappedAccounts: values[1] as List<SolanaWrappedNativeAccount>,
      associatedTokenAccountExists: values[2] as bool,
    );
  }

  _SolanaTransactionPlan _buildPlan({
    required SolanaWrappedNativeBalances balances,
    required String ownerAddress,
    required String blockhash,
    required WrappedNativeOperation operation,
    required BigInt amountLamports,
    required BigInt rentLamports,
  }) {
    if (operation == WrappedNativeOperation.wrap) {
      return _SolanaTransactionPlan(
        transaction: buildSolanaWrapTransaction(
          ownerAddress: ownerAddress,
          recentBlockhash: blockhash,
          amountLamports: amountLamports,
        ),
        accountRentLamports: balances.associatedTokenAccountExists
            ? BigInt.zero
            : rentLamports,
      );
    }
    if (amountLamports > balances.wrappedBalanceLamports) {
      throw StateError('insufficient_wrapped_balance');
    }
    if (amountLamports == balances.wrappedBalanceLamports) {
      return _SolanaTransactionPlan(
        transaction: buildSolanaFullUnwrapTransaction(
          ownerAddress: ownerAddress,
          recentBlockhash: blockhash,
          accounts: balances.wrappedAccounts
              .map((account) => account.address)
              .toList(growable: false),
        ),
        accountRentLamports: BigInt.zero,
        isFullUnwrap: true,
        accounts: balances.wrappedAccounts,
      );
    }
    final allocations = allocateSolanaWrappedNativeSources(
      amountLamports: amountLamports,
      accounts: balances.wrappedAccounts,
    );
    final temporaryKeypair = solana.Keypair.generate();
    return _SolanaTransactionPlan(
      transaction: buildSolanaPartialUnwrapTransaction(
        ownerAddress: ownerAddress,
        recentBlockhash: blockhash,
        temporaryAccountAddress: temporaryKeypair.publicKey.toBase58(),
        temporaryAccountRentLamports: rentLamports,
        allocations: allocations,
      ),
      accountRentLamports: rentLamports,
      allocations: allocations,
      temporaryKeypair: temporaryKeypair,
    );
  }

  solana.Transaction _rebuildTransaction({
    required String ownerAddress,
    required String blockhash,
    required SolanaWrappedNativePreparation preparation,
    required solana.Keypair? temporaryKeypair,
  }) {
    if (preparation.operation == WrappedNativeOperation.wrap) {
      return buildSolanaWrapTransaction(
        ownerAddress: ownerAddress,
        recentBlockhash: blockhash,
        amountLamports: preparation.amountLamports,
      );
    }
    if (preparation.isFullUnwrap) {
      return buildSolanaFullUnwrapTransaction(
        ownerAddress: ownerAddress,
        recentBlockhash: blockhash,
        accounts: preparation.accounts
            .map((account) => account.address)
            .toList(growable: false),
      );
    }
    if (temporaryKeypair == null) {
      throw StateError('missing_temporary_signer');
    }
    return buildSolanaPartialUnwrapTransaction(
      ownerAddress: ownerAddress,
      recentBlockhash: blockhash,
      temporaryAccountAddress: temporaryKeypair.publicKey.toBase58(),
      temporaryAccountRentLamports: preparation.accountRentLamports,
      allocations: preparation.allocations,
    );
  }

  void _validateFreshBalances(
    SolanaWrappedNativePreparation preparation,
    SolanaWrappedNativeBalances balances,
  ) {
    if (preparation.operation == WrappedNativeOperation.wrap) {
      return;
    }
    final freshByAddress = {
      for (final account in balances.wrappedAccounts) account.address: account,
    };
    if (preparation.isFullUnwrap) {
      if (freshByAddress.length != preparation.accounts.length) {
        throw StateError('wrapped_accounts_changed');
      }
      for (final account in preparation.accounts) {
        final fresh = freshByAddress[account.address];
        if (fresh == null || fresh.amountLamports != account.amountLamports) {
          throw StateError('wrapped_accounts_changed');
        }
      }
      return;
    }
    for (final allocation in preparation.allocations) {
      final fresh = freshByAddress[allocation.sourceAddress];
      if (fresh == null || fresh.amountLamports < allocation.amountLamports) {
        throw StateError('wrapped_accounts_changed');
      }
    }
  }

  SolanaWrappedNativeConnection _connection(
    String rpcUrl,
    Map<String, String> headers,
  ) {
    return (connectionFactory ?? _defaultSolanaConnection)(rpcUrl, headers);
  }
}

final class _SolanaTransactionPlan {
  _SolanaTransactionPlan({
    required this.transaction,
    required this.accountRentLamports,
    this.isFullUnwrap = false,
    this.accounts = const [],
    this.allocations = const [],
    this.temporaryKeypair,
  });

  final solana.Transaction transaction;
  final BigInt accountRentLamports;
  final bool isFullUnwrap;
  final List<SolanaWrappedNativeAccount> accounts;
  final List<SolanaWrappedNativeAllocation> allocations;
  final solana.Keypair? temporaryKeypair;
}

List<SolanaWrappedNativeAllocation> allocateSolanaWrappedNativeSources({
  required BigInt amountLamports,
  required List<SolanaWrappedNativeAccount> accounts,
}) {
  if (amountLamports <= BigInt.zero) {
    throw ArgumentError.value(amountLamports, 'amountLamports');
  }
  var remaining = amountLamports;
  final allocations = <SolanaWrappedNativeAllocation>[];
  for (final account in accounts) {
    if (remaining == BigInt.zero) {
      break;
    }
    if (account.amountLamports <= BigInt.zero) {
      continue;
    }
    final amount = account.amountLamports < remaining
        ? account.amountLamports
        : remaining;
    allocations.add(
      SolanaWrappedNativeAllocation(
        sourceAddress: account.address,
        amountLamports: amount,
      ),
    );
    remaining -= amount;
  }
  if (remaining > BigInt.zero) {
    throw StateError('insufficient_wrapped_balance');
  }
  return List.unmodifiable(allocations);
}

solana.Transaction buildSolanaWrapTransaction({
  required String ownerAddress,
  required String recentBlockhash,
  required BigInt amountLamports,
}) {
  if (amountLamports <= BigInt.zero) {
    throw ArgumentError.value(amountLamports, 'amountLamports');
  }
  final owner = solana.PublicKey.fromBase58(ownerAddress);
  final mint = solana.PublicKey.fromBase58(wrappedSolMintAddress);
  final ata = solana.AssociatedTokenProgram.getAssociatedTokenAddress(
    owner: owner,
    mint: mint,
  );
  return solana.Transaction(feePayer: owner, recentBlockhash: recentBlockhash)
    ..add(
      solana.AssociatedTokenProgram.createIdempotent(
        payer: owner,
        owner: owner,
        mint: mint,
      ),
    )
    ..add(
      solana.SystemProgram.transfer(
        fromPubkey: owner,
        toPubkey: ata,
        lamports: amountLamports,
      ),
    )
    ..add(solana.TokenProgram.token.syncNative(account: ata));
}

solana.Transaction buildSolanaFullUnwrapTransaction({
  required String ownerAddress,
  required String recentBlockhash,
  required List<String> accounts,
}) {
  if (accounts.isEmpty) {
    throw ArgumentError.value(accounts, 'accounts');
  }
  final owner = solana.PublicKey.fromBase58(ownerAddress);
  final transaction = solana.Transaction(
    feePayer: owner,
    recentBlockhash: recentBlockhash,
  );
  for (final account in accounts) {
    transaction.add(
      solana.TokenProgram.token.closeAccount(
        account: solana.PublicKey.fromBase58(account),
        destination: owner,
        owner: owner,
      ),
    );
  }
  return transaction;
}

solana.Transaction buildSolanaPartialUnwrapTransaction({
  required String ownerAddress,
  required String recentBlockhash,
  required String temporaryAccountAddress,
  required BigInt temporaryAccountRentLamports,
  required List<SolanaWrappedNativeAllocation> allocations,
}) {
  if (temporaryAccountRentLamports <= BigInt.zero || allocations.isEmpty) {
    throw ArgumentError('Partial unwrap requires rent and allocations');
  }
  final owner = solana.PublicKey.fromBase58(ownerAddress);
  final temporary = solana.PublicKey.fromBase58(temporaryAccountAddress);
  final mint = solana.PublicKey.fromBase58(wrappedSolMintAddress);
  final transaction =
      solana.Transaction(feePayer: owner, recentBlockhash: recentBlockhash)
        ..add(
          solana.SystemProgram.createAccount(
            fromPubkey: owner,
            newAccountPubkey: temporary,
            lamports: temporaryAccountRentLamports,
            space: solanaTokenAccountSize,
            programId: solana.TokenProgram.token.programId,
          ),
        )
        ..add(
          solana.TokenProgram.token.initializeAccount3(
            account: temporary,
            mint: mint,
            owner: owner,
          ),
        );
  for (final allocation in allocations) {
    transaction.add(
      solana.TokenProgram.token.transfer(
        source: solana.PublicKey.fromBase58(allocation.sourceAddress),
        destination: temporary,
        owner: owner,
        amount: allocation.amountLamports,
      ),
    );
  }
  transaction.add(
    solana.TokenProgram.token.closeAccount(
      account: temporary,
      destination: owner,
      owner: owner,
    ),
  );
  return transaction;
}

final class _SdkSolanaWrappedNativeConnection
    implements SolanaWrappedNativeConnection {
  _SdkSolanaWrappedNativeConnection(this._connection);

  final solana.Connection _connection;

  @override
  Future<BigInt> getBalance(solana.PublicKey owner) async {
    return BigInt.from(
      await _connection.getBalance(
        owner,
        commitment: solana.Commitment.confirmed,
      ),
    );
  }

  @override
  Future<List<SolanaWrappedNativeAccount>> getWrappedNativeAccounts(
    solana.PublicKey owner,
  ) async {
    final response = await _connection.getParsedTokenAccountsByOwner(
      owner,
      filter: solana.TokenAccountsFilter.mint(wrappedSolMintAddress),
      commitment: solana.Commitment.confirmed,
    );
    return response.value
        .map((account) => _wrappedAccount(account, owner.toBase58()))
        .whereType<SolanaWrappedNativeAccount>()
        .toList(growable: false);
  }

  @override
  Future<bool> accountExistsAt(solana.PublicKey address) async {
    return await _connection.getAccountInfo(
          address,
          commitment: solana.Commitment.confirmed,
        ) !=
        null;
  }

  @override
  Future<BigInt> getMinimumTokenAccountRent() async {
    return BigInt.from(
      await _connection.getMinimumBalanceForRentExemption(
        solanaTokenAccountSize,
        commitment: solana.Commitment.confirmed,
      ),
    );
  }

  @override
  Future<String> getLatestBlockhash() async {
    return (await _connection.getLatestBlockhash(
      commitment: solana.Commitment.confirmed,
    )).blockhash;
  }

  @override
  Future<BigInt> getEstimatedFee(solana.Transaction transaction) async {
    final response = await _connection.getFeeForMessage(
      transaction.compileMessage(),
      commitment: solana.Commitment.confirmed,
    );
    final fee = response.value;
    if (fee == null) {
      throw StateError('wrapped_native_fee_unavailable');
    }
    return BigInt.from(fee);
  }

  @override
  Future<void> simulate(solana.Transaction transaction) async {
    final response = await _connection.simulateTransaction(
      transaction,
      sigVerify: false,
      replaceRecentBlockhash: true,
      commitment: solana.Commitment.confirmed,
    );
    if (response.value.err != null) {
      throw StateError('wrapped_native_simulation_failed');
    }
  }

  @override
  Future<String> sendTransaction({
    required solana.Transaction transaction,
    required List<solana.Keypair> signers,
  }) async {
    transaction.sign(signers);
    return _connection.sendRawTransaction(
      transaction.serialize(),
      options: solana.SendOptions(
        preflightCommitment: solana.Commitment.confirmed,
      ),
    );
  }

  @override
  Future<void> confirmSignature(String signature) {
    return _connection.confirmSignature(
      signature,
      commitment: solana.Commitment.confirmed,
    );
  }

  @override
  Future<void> close() => _connection.close();
}

SolanaWrappedNativeAccount? _wrappedAccount(
  solana.TokenAccountInfo account,
  String ownerAddress,
) {
  if (account.account.owner != solana.TokenProgram.token.programId ||
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
  if (info is! Map ||
      info['owner'] != ownerAddress ||
      info['mint'] != wrappedSolMintAddress ||
      info['isNative'] != true) {
    return null;
  }
  final closeAuthority = info['closeAuthority'];
  if (closeAuthority != null && closeAuthority != ownerAddress) {
    return null;
  }
  final tokenAmount = info['tokenAmount'];
  if (tokenAmount is! Map) {
    return null;
  }
  final amount = BigInt.tryParse(tokenAmount['amount']?.toString() ?? '');
  if (amount == null || amount <= BigInt.zero) {
    return null;
  }
  return SolanaWrappedNativeAccount(
    address: account.pubkey.toBase58(),
    amountLamports: amount,
    accountLamports: BigInt.from(account.account.lamports),
  );
}

SolanaWrappedNativeConnection _defaultSolanaConnection(
  String rpcUrl,
  Map<String, String> headers,
) {
  final http.Client client = headers.isEmpty
      ? BoundedHttpClient()
      : HeaderHttpClient(headers: headers);
  return _SdkSolanaWrappedNativeConnection(
    solana.Connection(rpcUrl, httpClient: client),
  );
}
