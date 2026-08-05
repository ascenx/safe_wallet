import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/evm_token_discovery_service.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/assets/presentation/token_management_page.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Token discovery device smoke', () {
    testWidgets('discovers live ERC20 token through token management UI', (
      tester,
    ) async {
      await LocaleSettings.setLocale(AppLocale.en);
      final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      const client = Web3EvmTokenDiscoveryClient();
      final candidate = await tester.runAsync(
        () => _findRecentUsdcHolder(
          rpcUrl: chain.rpcUrls.first,
          client: client,
        ),
      );
      if (candidate == null) {
        fail('Unable to find a recent USDC holder for device discovery smoke');
      }

      final repository = _DeviceTokenRepository(
        initialLastScannedBlock: candidate.blockNumber,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenRepositoryProvider.overrideWithValue(repository),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: TokenManagementPage(
                chain: chain,
                rpcUrl: chain.rpcUrls.first,
                walletAddress: candidate.walletAddress,
              ),
            ),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('No tokens'));

      await tester.tap(find.text('Discover Tokens'));
      await _pumpUntilFound(tester, find.text('USDC'), maxPumps: 900);

      final savedToken = repository.savedTokens.singleWhere(
        (token) => token.contractAddress == _ethereumUsdcAddress,
      );
      expect(savedToken.name, 'USD Coin');
      expect(savedToken.symbol, 'USDC');
      expect(savedToken.decimals, 6);
      expect(savedToken.source, TokenSource.discovered);
      expect(repository.lastScannedBlock, isNotNull);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}

const _ethereumUsdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _transferTopic =
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 80,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  final visibleTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .toList(growable: false);
  fail('Timed out waiting for $finder. Visible texts: $visibleTexts');
}

Future<_TransferCandidate?> _findRecentUsdcHolder({
  required String rpcUrl,
  required EvmTokenDiscoveryClient client,
}) async {
  final latestBlock = await client.latestBlockNumber(rpcUrl: rpcUrl);

  for (final lookback in [20, 100, 500]) {
    final fromBlock = latestBlock > lookback ? latestBlock - lookback : 0;
    final logs = await _recentUsdcTransferLogs(
      rpcUrl: rpcUrl,
      fromBlock: fromBlock,
      toBlock: latestBlock,
    ).catchError((_) => const <Map<dynamic, dynamic>>[]);

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
  final response = await http.post(
    Uri.parse(rpcUrl),
    headers: const {'content-type': 'application/json'},
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

final class _DeviceTokenRepository implements TokenRepository {
  _DeviceTokenRepository({required int initialLastScannedBlock})
      : lastScannedBlock = initialLastScannedBlock;

  final _tokens = <String, TokenInfo>{};
  final savedTokens = <TokenInfo>[];
  int? lastScannedBlock;

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return _tokens.values
        .where((token) => token.chainId == chainId)
        .where((token) => includeHidden || !token.isHidden)
        .toList(growable: false);
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) async {
    final normalized = TokenInfo(
      chainId: token.chainId,
      contractAddress: token.contractAddress?.toLowerCase(),
      symbol: token.symbol,
      name: token.name,
      decimals: token.decimals,
      source: token.source,
      isHidden: token.isHidden,
      logoUri: token.logoUri,
    );
    _tokens[_tokenKey(normalized)] = normalized;
    savedTokens.add(normalized);
    return normalized;
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
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

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) async =>
      lastScannedBlock;

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) async {
    lastScannedBlock = blockNumber;
  }

  String _tokenKey(TokenInfo token) {
    return '${token.chainId}:${token.contractAddress?.toLowerCase()}';
  }
}
