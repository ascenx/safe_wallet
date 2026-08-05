import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:safe_wallet/features/assets/application/manual_token_add_controller.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/data/evm_token_discovery_service.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  const liveRpcEnabled = bool.hasEnvironment('SAFE_WALLET_LIVE_RPC')
      ? bool.fromEnvironment('SAFE_WALLET_LIVE_RPC')
      : false;
  final skipLiveRpc = liveRpcEnabled
      ? false
      : 'Set SAFE_WALLET_LIVE_RPC=true to run public RPC smoke tests.';

  group('live asset RPC smoke', () {
    test(
      'queries EVM native balance through the default public RPC',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final portfolio = await DefaultAssetRepository().loadPortfolio(
          account: _account,
          chain: chain,
          rpcNode: _defaultNodeFor(chain),
        );

        expect(portfolio.status, AssetPortfolioStatus.loaded);
        expect(portfolio.balances, hasLength(1));
        expect(portfolio.balances.single.token.symbol, chain.symbol);
        expect(_rawBalanceOf(portfolio.balances.single), isNonNegative);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'queries ERC20 balance through the default public RPC',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final portfolio = await DefaultAssetRepository().loadPortfolio(
          account: _account,
          chain: chain,
          rpcNode: _defaultNodeFor(chain),
          tokens: const [_ethereumUsdc],
        );

        expect(portfolio.status, AssetPortfolioStatus.loaded);
        expect(portfolio.balances, hasLength(2));
        final usdcBalance = portfolio.balances.singleWhere(
          (balance) => balance.token.contractAddress == _ethereumUsdcAddress,
        );
        expect(usdcBalance.token.symbol, 'USDC');
        expect(_rawBalanceOf(usdcBalance), isNonNegative);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'manual ERC20 add reads live balance and metadata before saving',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final repository = _RecordingTokenRepository();
        final container = ProviderContainer(
          overrides: [tokenRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final token = await container
            .read(manualTokenAddControllerProvider.notifier)
            .addToken(
              chain: chain,
              rpcUrl: chain.rpcUrls.first,
              walletAddress: _account.evmAddress,
              contractAddress: _ethereumUsdcAddress.toUpperCase(),
            );

        expect(token.contractAddress, _ethereumUsdcAddress);
        expect(token.name, 'USD Coin');
        expect(token.symbol, 'USDC');
        expect(token.decimals, 6);
        expect(token.source, TokenSource.userAdded);
        expect(repository.savedTokens, [token]);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'discovers ERC20 from live Transfer logs after balance confirmation',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        const client = Web3EvmTokenDiscoveryClient();
        final candidate = await _findRecentUsdcHolder(
          rpcUrl: chain.rpcUrls.first,
          client: client,
        );

        final result = await const EvmTokenDiscoveryService(client: client)
            .discover(
              chain: chain,
              rpcUrl: chain.rpcUrls.first,
              walletAddress: candidate.walletAddress,
              fromBlock: candidate.blockNumber,
            );

        expect(result.errorMessage, isNull);
        final token = result.tokens.singleWhere(
          (token) => token.contractAddress == _ethereumUsdcAddress,
        );
        expect(token.name, 'USD Coin');
        expect(token.symbol, 'USDC');
        expect(token.decimals, 6);
        expect(token.source, TokenSource.discovered);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 90)),
    );

    test(
      'queries Solana SOL balance through the default public RPC',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'solana-mainnet',
        );
        final portfolio = await DefaultAssetRepository().loadPortfolio(
          account: _account,
          chain: chain,
          rpcNode: _defaultNodeFor(chain),
        );

        expect(portfolio.status, AssetPortfolioStatus.loaded);
        expect(portfolio.balances, hasLength(1));
        expect(portfolio.balances.single.token.symbol, chain.symbol);
        expect(_rawBalanceOf(portfolio.balances.single), isNonNegative);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'queries Bitcoin BTC balance through the default public API',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'bitcoin-mainnet',
        );
        final portfolio = await DefaultAssetRepository().loadPortfolio(
          account: _account,
          chain: chain,
          rpcNode: _defaultNodeFor(chain),
        );

        expect(portfolio.status, AssetPortfolioStatus.loaded);
        expect(portfolio.balances, hasLength(1));
        expect(portfolio.balances.single.token.symbol, chain.symbol);
        expect(_rawBalanceOf(portfolio.balances.single), isNonNegative);
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'queries Solana SPL token balance through the default public RPC',
      () async {
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'solana-mainnet',
        );
        final holder = await _findRecentSolanaSplHolder(
          rpcUrl: chain.rpcUrls.first,
          mintAddress: _solanaUsdcMint,
        );
        final portfolio = await DefaultAssetRepository().loadPortfolio(
          account: _accountWithSolanaAddress(holder.ownerAddress),
          chain: chain,
          rpcNode: _defaultNodeFor(chain),
          tokens: const [_solanaUsdc],
        );

        expect(portfolio.status, AssetPortfolioStatus.loaded);
        expect(portfolio.balances, hasLength(2));
        final usdcBalance = portfolio.balances.singleWhere(
          (balance) => balance.token.contractAddress == _solanaUsdcMint,
        );
        expect(usdcBalance.token.symbol, 'USDC');
        expect(_rawBalanceOf(usdcBalance), greaterThan(BigInt.zero));
      },
      skip: skipLiveRpc,
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}

const _ethereumUsdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _solanaUsdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const _transferTopic =
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

const _ethereumUsdc = TokenInfo(
  chainId: '1',
  contractAddress: _ethereumUsdcAddress,
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);

const _solanaUsdc = TokenInfo(
  chainId: 'mainnet-beta',
  contractAddress: _solanaUsdcMint,
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);

final _account = WalletAccount(
  id: 'live-smoke-wallet',
  name: 'Live Smoke Wallet',
  evmAddress: '0x0000000000000000000000000000000000000000',
  solanaAddress: 'So11111111111111111111111111111111111111112',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

WalletAccount _accountWithSolanaAddress(String solanaAddress) {
  return WalletAccount(
    id: _account.id,
    name: _account.name,
    evmAddress: _account.evmAddress,
    solanaAddress: solanaAddress,
    createdAt: _account.createdAt,
    updatedAt: _account.updatedAt,
  );
}

RpcNode _defaultNodeFor(ChainConfig chain) {
  return RpcNode(
    id: '${chain.id}-default-live-smoke',
    chainId: chain.chainId,
    name: '${chain.name} Default',
    url: chain.rpcUrls.first,
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.untested,
  );
}

BigInt _rawBalanceOf(AssetBalance balance) {
  final rawBalance = balance.balance;
  expect(rawBalance, isNotNull);
  return BigInt.parse(rawBalance!);
}

Matcher get isNonNegative =>
    predicate<BigInt>((value) => value >= BigInt.zero, 'a non-negative BigInt');

Future<_TransferCandidate> _findRecentUsdcHolder({
  required String rpcUrl,
  required EvmTokenDiscoveryClient client,
}) async {
  final latestBlock = await client.latestBlockNumber(rpcUrl: rpcUrl);
  Object? lastError;

  for (final lookback in [20, 100, 500]) {
    final fromBlock = latestBlock > lookback ? latestBlock - lookback : 0;
    final logs =
        await _recentUsdcTransferLogs(
          rpcUrl: rpcUrl,
          fromBlock: fromBlock,
          toBlock: latestBlock,
        ).catchError((Object error) {
          lastError = error;
          return const <Map<dynamic, dynamic>>[];
        });

    for (final log in logs.reversed.take(40)) {
      final walletAddress = _transferRecipient(log);
      final blockNumber = _blockNumber(log);
      if (walletAddress == null || blockNumber == null) {
        continue;
      }
      final balance = await client.readBalance(
        rpcUrl: rpcUrl,
        contractAddress: _ethereumUsdcAddress,
        walletAddress: walletAddress,
      );
      if (balance > BigInt.zero) {
        return _TransferCandidate(
          walletAddress: walletAddress,
          blockNumber: blockNumber,
        );
      }
    }
  }

  throw StateError(
    'Unable to find a recent USDC holder for live discovery smoke. '
    'Last RPC error: $lastError',
  );
}

Future<_SolanaTokenHolder> _findRecentSolanaSplHolder({
  required String rpcUrl,
  required String mintAddress,
}) async {
  final result = await _postJsonRpc(
    rpcUrl: rpcUrl,
    method: 'getSignaturesForAddress',
    params: [
      mintAddress,
      {'limit': 5},
    ],
  );
  if (result is! List) {
    throw StateError('Invalid getSignaturesForAddress result for SPL smoke');
  }

  for (final entry in result.whereType<Map<dynamic, dynamic>>()) {
    final signature = entry['signature'];
    if (signature is! String) {
      continue;
    }
    final transaction = await _postJsonRpc(
      rpcUrl: rpcUrl,
      method: 'getTransaction',
      params: [
        signature,
        {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
      ],
    );
    final ownerAddress = _ownerFromSolanaPostTokenBalance(
      transaction,
      mintAddress: mintAddress,
    );
    if (ownerAddress != null) {
      return _SolanaTokenHolder(ownerAddress: ownerAddress);
    }
  }

  throw StateError('Unable to find a live SPL token holder for $mintAddress');
}

String? _ownerFromSolanaPostTokenBalance(
  Object? transaction, {
  required String mintAddress,
}) {
  final meta = transaction is Map ? transaction['meta'] : null;
  final balances = meta is Map ? meta['postTokenBalances'] : null;
  if (balances is! List) {
    return null;
  }

  for (final balance in balances.whereType<Map<dynamic, dynamic>>()) {
    if (balance['mint'] != mintAddress) {
      continue;
    }
    final tokenAmount = balance['uiTokenAmount'];
    final amount = tokenAmount is Map ? tokenAmount['amount'] : null;
    final owner = balance['owner'];
    if (amount is String &&
        (BigInt.tryParse(amount) ?? BigInt.zero) > BigInt.zero &&
        owner is String &&
        owner.isNotEmpty) {
      return owner;
    }
  }
  return null;
}

Future<List<Map<dynamic, dynamic>>> _recentUsdcTransferLogs({
  required String rpcUrl,
  required int fromBlock,
  required int toBlock,
}) async {
  final logs = await _postJsonRpc(
    rpcUrl: rpcUrl,
    method: 'eth_getLogs',
    params: [
      {
        'address': _ethereumUsdcAddress,
        'fromBlock': _hexQuantity(fromBlock),
        'toBlock': _hexQuantity(toBlock),
        'topics': const [_transferTopic],
      },
    ],
  );
  if (logs is! List) {
    throw StateError('Invalid eth_getLogs result for live USDC smoke');
  }
  return logs.whereType<Map<dynamic, dynamic>>().toList(growable: false);
}

Future<Object?> _postJsonRpc({
  required String rpcUrl,
  required String method,
  required List<Object?> params,
}) async {
  final request = jsonEncode({
    'jsonrpc': '2.0',
    'id': 1,
    'method': method,
    'params': params,
  });
  late http.Response response;
  for (var attempt = 0; attempt < 3; attempt += 1) {
    response = await http.post(
      Uri.parse(rpcUrl),
      headers: const {'content-type': 'application/json'},
      body: request,
    );
    if (response.statusCode != 429 || attempt == 2) {
      break;
    }
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    await Future<void>.delayed(
      Duration(seconds: (retryAfter ?? 2).clamp(1, 10)),
    );
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('RPC returned HTTP ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map || decoded['error'] != null) {
    throw StateError(
      'RPC returned an error: ${decoded is Map ? decoded['error'] : decoded}',
    );
  }
  return decoded['result'];
}

String? _transferRecipient(Map<dynamic, dynamic> log) {
  final topics = log['topics'];
  if (topics is! List || topics.length < 3) {
    return null;
  }
  final recipientTopic = topics[2];
  if (recipientTopic is! String || recipientTopic.length < 40) {
    return null;
  }
  return '0x${recipientTopic.substring(recipientTopic.length - 40)}'
      .toLowerCase();
}

int? _blockNumber(Map<dynamic, dynamic> log) {
  final blockNumber = log['blockNumber'];
  if (blockNumber is! String || !blockNumber.startsWith('0x')) {
    return null;
  }
  return BigInt.tryParse(blockNumber.substring(2), radix: 16)?.toInt();
}

String _hexQuantity(int value) => '0x${value.toRadixString(16)}';

final class _TransferCandidate {
  const _TransferCandidate({
    required this.walletAddress,
    required this.blockNumber,
  });

  final String walletAddress;
  final int blockNumber;
}

final class _SolanaTokenHolder {
  const _SolanaTokenHolder({required this.ownerAddress});

  final String ownerAddress;
}

final class _RecordingTokenRepository implements TokenRepository {
  final savedTokens = <TokenInfo>[];

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return List.unmodifiable(
      savedTokens.where((token) => token.chainId == chainId),
    );
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) async {
    savedTokens.add(token);
    return token;
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }
}
