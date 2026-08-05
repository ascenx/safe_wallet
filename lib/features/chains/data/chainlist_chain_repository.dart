import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../domain/chain_config.dart';

abstract interface class ChainlistChainRepository {
  Future<List<ChainConfig>> getChains();
}

final chainlistChainRepositoryProvider = Provider<ChainlistChainRepository>((
  ref,
) {
  final repository = DefaultChainlistChainRepository();
  ref.onDispose(repository.close);
  return repository;
});

final class DefaultChainlistChainRepository
    implements ChainlistChainRepository {
  DefaultChainlistChainRepository({http.Client? client, Uri? endpoint})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null,
      _endpoint = endpoint ?? Uri.parse('https://chainlist.org/rpcs.json');

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  List<ChainConfig>? _cachedChains;

  @override
  Future<List<ChainConfig>> getChains() async {
    final cached = _cachedChains;
    if (cached != null) {
      return cached;
    }

    final response = await _client.get(_endpoint);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const [];
    }

    final seenChainIds = <String>{};
    final chains = <ChainConfig>[];
    for (final entry in decoded.whereType<Map<String, Object?>>()) {
      final chain = _chainFromJson(entry);
      if (chain == null || !seenChainIds.add(chain.chainId)) {
        continue;
      }
      chains.add(chain);
    }
    chains.sort((left, right) => left.name.compareTo(right.name));
    _cachedChains = List.unmodifiable(chains);
    return _cachedChains!;
  }

  ChainConfig? _chainFromJson(Map<String, Object?> json) {
    final chainId = json['chainId']?.toString();
    final name = json['name'];
    final nativeCurrency = json['nativeCurrency'];
    final rpcUrls = _rpcUrls(json['rpc']);
    if (chainId == null ||
        chainId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        nativeCurrency is! Map<String, Object?> ||
        rpcUrls.isEmpty) {
      return null;
    }
    final symbol = nativeCurrency['symbol'];
    if (symbol is! String || symbol.isEmpty) {
      return null;
    }

    return ChainConfig(
      id: 'chainlist-$chainId',
      chainType: ChainType.evm,
      name: name,
      chainId: chainId,
      symbol: symbol,
      rpcUrls: rpcUrls,
      blockExplorerUrl: _blockExplorerUrl(json['explorers']),
      isTestnet: json['isTestnet'] == true,
    );
  }

  List<String> _rpcUrls(Object? rawValue) {
    if (rawValue is! List) {
      return const [];
    }
    final urls = <String>[];
    final seen = <String>{};
    for (final item in rawValue) {
      final url = switch (item) {
        final String value => value,
        {'url': final String value} => value,
        _ => null,
      };
      if (url == null || !_isUsableRpcUrl(url) || !seen.add(url)) {
        continue;
      }
      urls.add(url);
    }
    return List.unmodifiable(urls);
  }

  String? _blockExplorerUrl(Object? rawValue) {
    if (rawValue is! List) {
      return null;
    }
    for (final item in rawValue.whereType<Map<String, Object?>>()) {
      final url = item['url'];
      if (url is String && _isValidHttpUrl(url)) {
        return url;
      }
    }
    return null;
  }

  bool _isUsableRpcUrl(String value) {
    if (value.contains(r'$') || value.contains('{') || value.contains('}')) {
      return false;
    }
    return _isValidHttpUrl(value);
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
