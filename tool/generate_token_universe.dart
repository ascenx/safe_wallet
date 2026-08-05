import 'dart:convert';
import 'dart:io';

const _chainSources = [
  _ChainSource(
    chainId: '1',
    platformId: 'ethereum',
    tokenListSlug: 'ethereum',
  ),
  _ChainSource(
    chainId: '56',
    platformId: 'binance-smart-chain',
    tokenListSlug: 'binance-smart-chain',
  ),
  _ChainSource(
    chainId: '137',
    platformId: 'polygon-pos',
    tokenListSlug: 'polygon-pos',
  ),
  _ChainSource(
    chainId: '42161',
    platformId: 'arbitrum-one',
    tokenListSlug: 'arbitrum-one',
  ),
  _ChainSource(
    chainId: '10',
    platformId: 'optimistic-ethereum',
    tokenListSlug: 'optimistic-ethereum',
  ),
  _ChainSource(
    chainId: '8453',
    platformId: 'base',
    tokenListSlug: 'base',
  ),
  _ChainSource(
    chainId: 'solana',
    platformId: 'solana',
    tokenListSlug: 'solana',
  ),
];

const _marketPages = 10;
const _marketPageSize = 250;
const _topTokenLimit = 100;
const _requestDelay = Duration(seconds: 2);
const _rateLimitDelay = Duration(seconds: 65);

Future<void> main() async {
  final client = HttpClient();
  try {
    final rankedCoinIds = await _loadRankedCoinIds(client);
    final platformRanks = await _loadPlatformRanks(
      client: client,
      rankedCoinIds: rankedCoinIds,
    );

    final outputDirectory = Directory('assets/token_universe');
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }

    for (final chain in _chainSources) {
      final tokenList = await _loadTokenList(client, chain.tokenListSlug);
      final rankedTokens = _rankTokens(
        chain: chain,
        tokenList: tokenList,
        platformRanks: platformRanks[chain.platformId] ?? const {},
      );
      final file = File('${outputDirectory.path}/${chain.chainId}.json');
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'chainId': chain.chainId,
          'source': {
            'name': 'CoinGecko',
            'markets':
                'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc',
            'platforms':
                'https://api.coingecko.com/api/v3/coins/list?include_platform=true',
            'tokenList':
                'https://tokens.coingecko.com/${chain.tokenListSlug}/all.json',
          },
          'tokens': rankedTokens.take(_topTokenLimit).toList(growable: false),
        }),
      );
      stdout.writeln(
        '${chain.chainId}: wrote ${rankedTokens.take(_topTokenLimit).length} tokens',
      );
    }
  } finally {
    client.close(force: true);
  }
}

Future<List<String>> _loadRankedCoinIds(HttpClient client) async {
  final rankedIds = <String>[];
  for (var page = 1; page <= _marketPages; page += 1) {
    final uri = Uri.https('api.coingecko.com', '/api/v3/coins/markets', {
      'vs_currency': 'usd',
      'order': 'market_cap_desc',
      'per_page': _marketPageSize.toString(),
      'page': page.toString(),
      'sparkline': 'false',
    });
    final data = await _getJson(client, uri);
    await Future<void>.delayed(_requestDelay);
    if (data is! List) {
      continue;
    }
    for (final coin in data) {
      if (coin case {'id': final String id}) {
        rankedIds.add(id);
      }
    }
  }
  return rankedIds;
}

Future<Map<String, Map<String, int>>> _loadPlatformRanks({
  required HttpClient client,
  required List<String> rankedCoinIds,
}) async {
  final rankByCoinId = {
    for (final entry in rankedCoinIds.indexed) entry.$2: entry.$1,
  };
  final data = await _getJson(
    client,
    Uri.https('api.coingecko.com', '/api/v3/coins/list', {
      'include_platform': 'true',
    }),
  );
  await Future<void>.delayed(_requestDelay);
  if (data is! List) {
    return const {};
  }

  final ranks = <String, Map<String, int>>{};
  for (final coin in data) {
    if (coin is! Map<String, dynamic>) {
      continue;
    }
    final id = coin['id'];
    final rank = id is String ? rankByCoinId[id] : null;
    final platforms = coin['platforms'];
    if (rank == null || platforms is! Map<String, dynamic>) {
      continue;
    }
    for (final entry in platforms.entries) {
      final address = entry.value;
      if (address is! String || address.isEmpty) {
        continue;
      }
      ranks.putIfAbsent(entry.key, () => {})[_normalizeAddress(
        platformId: entry.key,
        address: address,
      )] = rank;
    }
  }
  return ranks;
}

Future<List<Map<String, dynamic>>> _loadTokenList(
  HttpClient client,
  String slug,
) async {
  final data = await _getJson(
    client,
    Uri.https('tokens.coingecko.com', '/$slug/all.json'),
  );
  await Future<void>.delayed(_requestDelay);
  if (data case {'tokens': final List<dynamic> tokens}) {
    return tokens.whereType<Map<String, dynamic>>().toList(growable: false);
  }
  return const [];
}

List<Map<String, Object?>> _rankTokens({
  required _ChainSource chain,
  required List<Map<String, dynamic>> tokenList,
  required Map<String, int> platformRanks,
}) {
  final ranked = <_RankedToken>[];
  final unranked = <Map<String, Object?>>[];
  final seenAddresses = <String>{};
  for (final token in tokenList) {
    final address = token['address'];
    final symbol = token['symbol'];
    final name = token['name'];
    final decimals = token['decimals'];
    if (address is! String ||
        address.isEmpty ||
        symbol is! String ||
        symbol.isEmpty ||
        name is! String ||
        name.isEmpty ||
        decimals is! num) {
      continue;
    }
    final normalizedAddress = _normalizeAddress(
      platformId: chain.platformId,
      address: address,
    );
    if (!seenAddresses.add(normalizedAddress)) {
      continue;
    }
    final logoUri = _largeLogoUri(token['logoURI']);
    final normalizedToken = {
      'chainId': chain.chainId,
      'contractAddress': address,
      'symbol': symbol,
      'name': name,
      'decimals': decimals.toInt(),
      'logoUri': ?logoUri,
    };
    final rank = platformRanks[normalizedAddress];
    if (rank == null) {
      unranked.add(normalizedToken);
      continue;
    }
    ranked.add(
      _RankedToken(
        rank: rank,
        token: normalizedToken,
      ),
    );
  }

  ranked.sort((left, right) => left.rank.compareTo(right.rank));
  return [
    ...ranked.map((entry) => entry.token),
    ...unranked,
  ];
}

String? _largeLogoUri(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value
      .replaceAll('/thumb/', '/large/')
      .replaceAll('/small/', '/large/');
}

Future<Object?> _getJson(HttpClient client, Uri uri) async {
  const maxAttempts = 3;
  for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
    final response = await _getResponse(client, uri);
    if (response.statusCode == 429 && attempt < maxAttempts) {
      await response.drain<void>();
      stderr.writeln('Rate limited by CoinGecko, waiting $_rateLimitDelay...');
      await Future<void>.delayed(_rateLimitDelay);
      continue;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'GET $uri returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return jsonDecode(await response.transform(utf8.decoder).join());
  }
  throw HttpException('GET $uri failed after retries', uri: uri);
}

Future<HttpClientResponse> _getResponse(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  return request.close();
}

String _normalizeAddress({
  required String platformId,
  required String address,
}) {
  return platformId == 'solana' ? address : address.toLowerCase();
}

final class _ChainSource {
  const _ChainSource({
    required this.chainId,
    required this.platformId,
    required this.tokenListSlug,
  });

  final String chainId;
  final String platformId;
  final String tokenListSlug;
}

final class _RankedToken {
  const _RankedToken({
    required this.rank,
    required this.token,
  });

  final int rank;
  final Map<String, Object?> token;
}
