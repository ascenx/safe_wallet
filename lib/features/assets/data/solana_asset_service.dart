import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/errors/rpc_error.dart';
import '../../../shared/network/bounded_http_client.dart';

abstract interface class SolanaAssetService {
  Future<BigInt> getSolBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<BigInt> getSplTokenBalance({
    required String rpcUrl,
    required String ownerAddress,
    required String mintAddress,
    Map<String, String> headers = const {},
  });

  Future<List<SolanaTokenBalance>> getTokenBalancesByOwner({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  });
}

final class SolanaTokenBalance {
  const SolanaTokenBalance({
    required this.mintAddress,
    required this.rawBalance,
    required this.decimals,
  });

  final String mintAddress;
  final BigInt rawBalance;
  final int decimals;
}

final class HttpSolanaAssetService implements SolanaAssetService {
  HttpSolanaAssetService({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<BigInt> getSolBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final result = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'getBalance',
      params: [walletAddress],
      headers: headers,
    );
    final value = (result as Map)['value'];
    if (value is! num) {
      throw const RpcError.unavailable(
        debugMessage: 'Solana getBalance result is invalid',
      );
    }
    return BigInt.from(value);
  }

  @override
  Future<BigInt> getSplTokenBalance({
    required String rpcUrl,
    required String ownerAddress,
    required String mintAddress,
    Map<String, String> headers = const {},
  }) async {
    final result = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'getTokenAccountsByOwner',
      params: [
        ownerAddress,
        {'mint': mintAddress},
        {'encoding': 'jsonParsed'},
      ],
      headers: headers,
    );
    final accounts = (result as Map)['value'];
    if (accounts is! List) {
      throw const RpcError.unavailable(
        debugMessage: 'Solana token account result is invalid',
      );
    }

    var total = BigInt.zero;
    for (final account in accounts) {
      final amount = _tokenAmountFromAccount(account);
      if (amount != null) {
        total += amount;
      }
    }
    return total;
  }

  @override
  Future<List<SolanaTokenBalance>> getTokenBalancesByOwner({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  }) async {
    final balancesByMint = <String, SolanaTokenBalance>{};
    for (final programId in solanaTokenProgramIds) {
      final balances = await _getTokenBalancesByOwnerForProgram(
        rpcUrl: rpcUrl,
        ownerAddress: ownerAddress,
        programId: programId,
        headers: headers,
      );
      for (final balance in balances) {
        final existing = balancesByMint[balance.mintAddress];
        balancesByMint[balance.mintAddress] = SolanaTokenBalance(
          mintAddress: balance.mintAddress,
          rawBalance:
              (existing?.rawBalance ?? BigInt.zero) + balance.rawBalance,
          decimals: existing?.decimals ?? balance.decimals,
        );
      }
    }
    return balancesByMint.values.toList(growable: false);
  }

  Future<List<SolanaTokenBalance>> _getTokenBalancesByOwnerForProgram({
    required String rpcUrl,
    required String ownerAddress,
    required String programId,
    required Map<String, String> headers,
  }) async {
    try {
      return await _getTokenBalancesByOwnerRpc(
        rpcUrl: rpcUrl,
        ownerAddress: ownerAddress,
        programId: programId,
        headers: headers,
      );
    } on RpcError {
      if (programId != splTokenProgramId) {
        rethrow;
      }
      return _getSplTokenBalancesByProgramAccounts(
        rpcUrl: rpcUrl,
        ownerAddress: ownerAddress,
        headers: headers,
      );
    }
  }

  Future<List<SolanaTokenBalance>> _getTokenBalancesByOwnerRpc({
    required String rpcUrl,
    required String ownerAddress,
    required String programId,
    required Map<String, String> headers,
  }) async {
    final result = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'getTokenAccountsByOwner',
      params: [
        ownerAddress,
        {'programId': programId},
        {'encoding': 'jsonParsed'},
      ],
      headers: headers,
    );
    final accounts = (result as Map)['value'];
    if (accounts is! List) {
      throw const RpcError.unavailable(
        debugMessage: 'Solana token account result is invalid',
      );
    }
    return _tokenBalancesFromAccounts(accounts);
  }

  Future<List<SolanaTokenBalance>> _getSplTokenBalancesByProgramAccounts({
    required String rpcUrl,
    required String ownerAddress,
    required Map<String, String> headers,
  }) async {
    final result = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'getProgramAccounts',
      params: [
        splTokenProgramId,
        {
          'encoding': 'jsonParsed',
          'filters': [
            {'dataSize': 165},
            {
              'memcmp': {'offset': 32, 'bytes': ownerAddress},
            },
          ],
        },
      ],
      headers: headers,
    );
    if (result is! List) {
      throw const RpcError.unavailable(
        debugMessage: 'Solana program account result is invalid',
      );
    }
    return _tokenBalancesFromAccounts(result);
  }

  List<SolanaTokenBalance> _tokenBalancesFromAccounts(List<Object?> accounts) {
    final balances = <SolanaTokenBalance>[];
    for (final account in accounts) {
      final balance = _tokenBalanceFromAccount(account);
      if (balance == null) {
        continue;
      }
      balances.add(balance);
    }
    return balances;
  }

  Future<Object?> _postJsonRpc({
    required String rpcUrl,
    required String method,
    required List<Object?> params,
    required Map<String, String> headers,
  }) async {
    final uri = _parseRpcUri(rpcUrl);
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Solana RPC returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['error'] != null) {
      throw const RpcError.unavailable();
    }
    return decoded['result'];
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

const splTokenProgramId = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA';
const token2022ProgramId = 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb';
const solanaTokenProgramIds = [splTokenProgramId, token2022ProgramId];

BigInt? _tokenAmountFromAccount(Object? account) {
  return _tokenBalanceFromAccount(account)?.rawBalance;
}

SolanaTokenBalance? _tokenBalanceFromAccount(Object? account) {
  if (account is! Map) {
    return null;
  }
  final accountData = account['account'];
  if (accountData is! Map) {
    return null;
  }
  final data = accountData['data'];
  if (data is! Map) {
    return null;
  }
  final parsed = data['parsed'];
  if (parsed is! Map) {
    return null;
  }
  final info = parsed['info'];
  if (info is! Map) {
    return null;
  }
  final mintAddress = info['mint'];
  if (mintAddress is! String || mintAddress.isEmpty) {
    return null;
  }
  final tokenAmount = info['tokenAmount'];
  if (tokenAmount is! Map) {
    return null;
  }
  final amount = tokenAmount['amount'];
  if (amount is! String) {
    return null;
  }
  final rawBalance = BigInt.tryParse(amount);
  if (rawBalance == null) {
    return null;
  }
  final decimals = tokenAmount['decimals'];
  if (decimals is! num) {
    return null;
  }
  return SolanaTokenBalance(
    mintAddress: mintAddress,
    rawBalance: rawBalance,
    decimals: decimals.toInt(),
  );
}

Uri _parseRpcUri(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const RpcError.invalidUrl();
  }
  return uri;
}
