import 'dart:convert';

import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/header_http_client.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/token_info.dart';

abstract interface class EvmTokenDiscoveryClient {
  Future<int> latestBlockNumber({
    required String rpcUrl,
    Map<String, String> headers = const {},
  });

  Future<List<String>> scanTransferContracts({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    Map<String, String> headers = const {},
  });

  Future<EvmTokenMetadata> readMetadata({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  });

  Future<BigInt> readBalance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  });
}

final class EvmTokenMetadata {
  const EvmTokenMetadata({
    required this.name,
    required this.symbol,
    required this.decimals,
  });

  final String name;
  final String symbol;
  final int decimals;
}

final class EvmTokenDiscoveryResult {
  const EvmTokenDiscoveryResult({
    required this.tokens,
    required this.lastScannedBlock,
    this.errorMessage,
  });

  final List<TokenInfo> tokens;
  final int? lastScannedBlock;
  final String? errorMessage;
}

final class EvmTokenDiscoveryService {
  const EvmTokenDiscoveryService({
    EvmTokenDiscoveryClient client = const Web3EvmTokenDiscoveryClient(),
    int maxScanBlockRange = 5000,
  }) : _client = client,
       _maxScanBlockRange = maxScanBlockRange,
       assert(maxScanBlockRange > 0);

  final EvmTokenDiscoveryClient _client;
  final int _maxScanBlockRange;

  Future<EvmTokenDiscoveryResult> discover({
    required ChainConfig chain,
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    List<TokenInfo>? candidateTokens,
    Map<String, String> rpcHeaders = const {},
  }) async {
    try {
      if (candidateTokens != null) {
        return await _discoverCandidateTokens(
          chain: chain,
          rpcUrl: rpcUrl,
          walletAddress: walletAddress,
          candidateTokens: candidateTokens,
          rpcHeaders: rpcHeaders,
        );
      }
      final latestBlock = await _client.latestBlockNumber(
        rpcUrl: rpcUrl,
        headers: rpcHeaders,
      );
      final contracts = await _scanTransferContractsInRanges(
        rpcUrl: rpcUrl,
        walletAddress: walletAddress,
        fromBlock: fromBlock,
        toBlock: latestBlock,
        headers: rpcHeaders,
      );
      final tokens = <TokenInfo>[];
      final seen = <String>{};
      for (final contract in contracts) {
        final normalizedContract = contract.toLowerCase();
        if (!seen.add(normalizedContract)) {
          continue;
        }
        final balance = await _client.readBalance(
          rpcUrl: rpcUrl,
          contractAddress: normalizedContract,
          walletAddress: walletAddress,
          headers: rpcHeaders,
        );
        if (balance <= BigInt.zero) {
          continue;
        }

        final metadata = await _client.readMetadata(
          rpcUrl: rpcUrl,
          contractAddress: normalizedContract,
        );
        tokens.add(
          TokenInfo(
            chainId: chain.chainId,
            contractAddress: normalizedContract,
            symbol: metadata.symbol,
            name: metadata.name,
            decimals: metadata.decimals,
            source: TokenSource.discovered,
            isHidden: false,
          ),
        );
      }
      return EvmTokenDiscoveryResult(
        tokens: List.unmodifiable(tokens),
        lastScannedBlock: latestBlock,
      );
    } catch (error) {
      return EvmTokenDiscoveryResult(
        tokens: const [],
        lastScannedBlock: null,
        errorMessage: error.toString(),
      );
    }
  }

  Future<EvmTokenDiscoveryResult> _discoverCandidateTokens({
    required ChainConfig chain,
    required String rpcUrl,
    required String walletAddress,
    required List<TokenInfo> candidateTokens,
    required Map<String, String> rpcHeaders,
  }) async {
    final discovered = <TokenInfo>[];
    final candidates = candidateTokens
        .where((token) => token.contractAddress != null)
        .toList(growable: false);
    for (var start = 0; start < candidates.length; start += 10) {
      final candidateEnd = start + 10;
      final end = candidateEnd < candidates.length
          ? candidateEnd
          : candidates.length;
      final results = await Future.wait(
        candidates.sublist(start, end).map((token) async {
          final balance = await _client.readBalance(
            rpcUrl: rpcUrl,
            contractAddress: token.contractAddress!,
            walletAddress: walletAddress,
            headers: rpcHeaders,
          );
          if (balance <= BigInt.zero) {
            return null;
          }
          return TokenInfo(
            chainId: chain.chainId,
            contractAddress: token.contractAddress,
            symbol: token.symbol,
            name: token.name,
            decimals: token.decimals,
            logoUri: token.logoUri,
            source: TokenSource.discovered,
            isHidden: false,
            requiresMemo: token.requiresMemo,
            memoLabel: token.memoLabel,
          );
        }),
      );
      discovered.addAll(results.nonNulls);
    }
    return EvmTokenDiscoveryResult(
      tokens: List.unmodifiable(discovered),
      lastScannedBlock: null,
    );
  }

  Future<List<String>> _scanTransferContractsInRanges({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    required Map<String, String> headers,
  }) async {
    if (fromBlock > toBlock) {
      return const [];
    }

    final contracts = <String>[];
    var rangeStart = fromBlock;
    while (rangeStart <= toBlock) {
      final candidateEnd = rangeStart + _maxScanBlockRange - 1;
      final rangeEnd = candidateEnd < toBlock ? candidateEnd : toBlock;
      contracts.addAll(
        await _client.scanTransferContracts(
          rpcUrl: rpcUrl,
          walletAddress: walletAddress,
          fromBlock: rangeStart,
          toBlock: rangeEnd,
          headers: headers,
        ),
      );
      rangeStart = rangeEnd + 1;
    }
    return contracts;
  }
}

final class Web3EvmTokenDiscoveryClient implements EvmTokenDiscoveryClient {
  const Web3EvmTokenDiscoveryClient();

  @override
  Future<int> latestBlockNumber({
    required String rpcUrl,
    Map<String, String> headers = const {},
  }) async {
    final response = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'eth_blockNumber',
      params: const [],
      headers: headers,
    );
    if (response is! String || !response.startsWith('0x')) {
      throw StateError('Invalid eth_blockNumber result');
    }
    return BigInt.parse(response.substring(2), radix: 16).toInt();
  }

  @override
  Future<List<String>> scanTransferContracts({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    Map<String, String> headers = const {},
  }) async {
    final walletTopic = _addressTopic(walletAddress);
    final fromContracts = await _scanLogs(
      rpcUrl: rpcUrl,
      fromBlock: fromBlock,
      toBlock: toBlock,
      topics: [_transferTopic, walletTopic],
      headers: headers,
    );
    final toContracts = await _scanLogs(
      rpcUrl: rpcUrl,
      fromBlock: fromBlock,
      toBlock: toBlock,
      topics: [_transferTopic, null, walletTopic],
      headers: headers,
    );
    return {...fromContracts, ...toContracts}.toList();
  }

  @override
  Future<EvmTokenMetadata> readMetadata({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    final client = Web3Client(
      rpcUrl,
      headers.isEmpty
          ? BoundedHttpClient()
          : HeaderHttpClient(headers: headers),
    );
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20MetadataAbi, 'ERC20Metadata'),
        EthereumAddress.fromHex(contractAddress),
      );
      final nameResult = await client.call(
        contract: contract,
        function: contract.function('name'),
        params: const [],
      );
      final symbolResult = await client.call(
        contract: contract,
        function: contract.function('symbol'),
        params: const [],
      );
      final decimalsResult = await client.call(
        contract: contract,
        function: contract.function('decimals'),
        params: const [],
      );
      return EvmTokenMetadata(
        name: nameResult.first as String,
        symbol: symbolResult.first as String,
        decimals: (decimalsResult.first as BigInt).toInt(),
      );
    } finally {
      client.dispose();
    }
  }

  @override
  Future<BigInt> readBalance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final client = Web3Client(
      rpcUrl,
      headers.isEmpty
          ? BoundedHttpClient()
          : HeaderHttpClient(headers: headers),
    );
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20BalanceAbi, 'ERC20Balance'),
        EthereumAddress.fromHex(contractAddress),
      );
      final result = await client.call(
        contract: contract,
        function: contract.function('balanceOf'),
        params: [EthereumAddress.fromHex(walletAddress)],
      );
      return result.first as BigInt;
    } finally {
      client.dispose();
    }
  }

  Future<List<String>> _scanLogs({
    required String rpcUrl,
    required int fromBlock,
    required int toBlock,
    required List<String?> topics,
    required Map<String, String> headers,
  }) async {
    final logs = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'eth_getLogs',
      params: [
        {
          'fromBlock': _hexQuantity(fromBlock),
          'toBlock': _hexQuantity(toBlock),
          'topics': topics,
        },
      ],
      headers: headers,
    );
    if (logs is! List) {
      throw StateError('Invalid eth_getLogs result');
    }
    return logs
        .whereType<Map>()
        .map((log) => log['address'])
        .whereType<String>()
        .map((address) => address.toLowerCase())
        .toList();
  }

  Future<Object?> _postJsonRpc({
    required String rpcUrl,
    required String method,
    required List<Object?> params,
    required Map<String, String> headers,
  }) async {
    final client = BoundedHttpClient();
    try {
      final response = await client.post(
        Uri.parse(rpcUrl),
        headers: {'content-type': 'application/json', ...headers},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': params,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('RPC returned HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['error'] != null) {
        throw StateError('RPC returned an error');
      }
      return decoded['result'];
    } finally {
      client.close();
    }
  }
}

String _addressTopic(String address) {
  final normalized = address.toLowerCase().replaceFirst('0x', '');
  return '0x${normalized.padLeft(64, '0')}';
}

String _hexQuantity(int value) => '0x${value.toRadixString(16)}';

const _transferTopic =
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

const _erc20MetadataAbi = '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "name",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "symbol",
    "outputs": [{"name": "", "type": "string"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "type": "function"
  }
]
''';

const _erc20BalanceAbi = '''
[
  {
    "constant": true,
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  }
]
''';
