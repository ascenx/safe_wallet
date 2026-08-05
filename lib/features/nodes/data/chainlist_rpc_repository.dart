import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/rpc_node.dart';

abstract interface class ChainlistRpcRepository {
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain);
}

final chainlistRpcRepositoryProvider = Provider<ChainlistRpcRepository>((ref) {
  final repository = DefaultChainlistRpcRepository();
  ref.onDispose(repository.close);
  return repository;
});

final class DefaultChainlistRpcRepository implements ChainlistRpcRepository {
  DefaultChainlistRpcRepository({http.Client? client, Uri? endpoint})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null,
      _endpoint = endpoint ?? Uri.parse('https://chainlist.org/rpcs.json');

  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  List<Object?>? _cachedPayload;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    if (chain.chainType != ChainType.evm) {
      return const [];
    }
    final payload = await _loadPayload();
    final chainPayload = payload.whereType<Map<String, Object?>>().firstWhere(
      (entry) => entry['chainId']?.toString() == chain.chainId,
      orElse: () => const {},
    );
    if (chainPayload.isEmpty) {
      return const [];
    }

    final seenUrls = <String>{};
    final nodes = <RpcNode>[];
    for (final endpoint in _rpcEndpoints(chainPayload['rpc'])) {
      final url = endpoint.url;
      if (!_isUsableRpcUrl(url) || !seenUrls.add(url)) {
        continue;
      }
      nodes.add(
        RpcNode(
          id: 'chainlist-${chain.chainId}-${_stableHash(url)}',
          chainId: chain.chainId,
          name: _displayNameFor(url),
          url: url,
          nodeType: RpcNodeType.chainlist,
          isSelected: false,
          lastTestStatus: RpcNodeTestStatus.untested,
          provider: RpcProvider.public,
          note: endpoint.tracking == null
              ? null
              : 'tracking:${endpoint.tracking}',
        ),
      );
    }
    return List.unmodifiable(nodes);
  }

  Future<List<Object?>> _loadPayload() async {
    final cached = _cachedPayload;
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
    _cachedPayload = decoded.cast<Object?>();
    return _cachedPayload!;
  }

  Iterable<_ChainlistRpcEndpoint> _rpcEndpoints(Object? rawValue) sync* {
    if (rawValue is! List) {
      return;
    }
    for (final item in rawValue) {
      if (item is String) {
        yield _ChainlistRpcEndpoint(url: item);
        continue;
      }
      if (item is Map<String, Object?>) {
        final url = item['url'];
        if (url is! String) {
          continue;
        }
        final tracking = item['tracking'];
        yield _ChainlistRpcEndpoint(
          url: url,
          tracking: tracking is String ? tracking : null,
        );
      }
    }
  }

  bool _isUsableRpcUrl(String value) {
    if (value.contains(r'$') || value.contains('{') || value.contains('}')) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  String _displayNameFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return url;
    }
    return uri.host;
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = (hash ^ unit) * 0x01000193;
      hash &= 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

final class _ChainlistRpcEndpoint {
  const _ChainlistRpcEndpoint({required this.url, this.tracking});

  final String url;
  final String? tracking;
}
