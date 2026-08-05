import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../domain/rpc_node.dart';
import 'rpc_credential_store.dart';

final class RpcCredentialMigration {
  const RpcCredentialMigration({
    required HiveBoxRegistry registry,
    required RpcCredentialStore credentialStore,
    StorageJsonCodec codec = const StorageJsonCodec(),
  })  : _registry = registry,
        _credentialStore = credentialStore,
        _codec = codec;

  final HiveBoxRegistry _registry;
  final RpcCredentialStore _credentialStore;
  final StorageJsonCodec _codec;

  Future<void> apply() async {
    await _migrateStoredNodes();
    await _migrateStoredChains();
  }

  Future<void> _migrateStoredNodes() async {
    for (final key in _registry.rpcNodesBox.keys.toList(growable: false)) {
      final rawValue = _registry.rpcNodesBox.get(key);
      if (rawValue is! String) {
        continue;
      }
      final json = _codec.decode(rawValue);
      if (json['credentialMode'] != null) {
        continue;
      }
      final url = json['url'];
      final id = json['id'];
      if (url is! String || id is! String) {
        continue;
      }
      final extracted = parsePrivateRpcEndpoint(url);
      if (extracted == null) {
        continue;
      }
      await _storeMigratedNode(
        nodeId: id,
        json: json,
        extracted: extracted,
      );
    }
  }

  Future<void> _migrateStoredChains() async {
    for (final key in _registry.chainsBox.keys.toList(growable: false)) {
      final rawValue = _registry.chainsBox.get(key);
      if (rawValue is! String) {
        continue;
      }
      final json = _codec.decode(rawValue);
      final urls = json['rpcUrls'];
      final chainId = json['chainId'];
      final chainName = json['name'];
      final chainStorageId = json['id'];
      if (urls is! List ||
          chainId is! String ||
          chainName is! String ||
          chainStorageId is! String) {
        continue;
      }

      var changed = false;
      final sanitizedUrls = <String>[];
      for (var index = 0; index < urls.length; index += 1) {
        final url = urls[index];
        if (url is! String) {
          continue;
        }
        final extracted = parsePrivateRpcEndpoint(url);
        if (extracted == null) {
          sanitizedUrls.add(url);
          continue;
        }
        changed = true;
        sanitizedUrls.add(extracted.safeUrl);
        final nodeId = '$chainStorageId-default-$index';
        final existingRaw = _registry.rpcNodesBox.get(nodeId);
        final nodeJson = existingRaw is String
            ? _codec.decode(existingRaw)
            : <String, Object?>{
                'id': nodeId,
                'chainId': chainId,
                'name': urls.length == 1
                    ? '$chainName Default'
                    : '$chainName Default ${index + 1}',
                'url': url,
                'nodeType': RpcNodeType.defaultNode.name,
                'isSelected': index == 0,
                'lastTestStatus': RpcNodeTestStatus.untested.name,
              };
        await _storeMigratedNode(
          nodeId: nodeId,
          json: nodeJson,
          extracted: extracted,
        );
      }
      if (changed) {
        await _registry.chainsBox.put(
          key,
          _codec.encode({...json, 'rpcUrls': sanitizedUrls}),
        );
      }
    }
  }

  Future<void> _storeMigratedNode({
    required String nodeId,
    required Map<String, Object?> json,
    required ParsedPrivateRpcEndpoint extracted,
  }) async {
    final credentialRef = 'rpc-node.$nodeId';
    await _credentialStore.write(credentialRef, extracted.credential);
    await _registry.rpcNodesBox.put(
      nodeId,
      _codec.encode({
        ...json,
        'url': extracted.safeUrl,
        'provider': extracted.provider.name,
        'credentialMode': extracted.mode.name,
        'credentialParameter': extracted.parameter,
        'credentialRef': credentialRef,
      }),
    );
  }
}

ParsedPrivateRpcEndpoint? parsePrivateRpcEndpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) {
    return null;
  }
  final host = uri.host.toLowerCase();
  if (host.endsWith('helius-rpc.com')) {
    final credential = uri.queryParameters['api-key'];
    if (credential == null || credential.isEmpty) {
      return null;
    }
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..remove('api-key');
    final safeUri = queryParameters.isEmpty
        ? _rebuildUri(uri)
        : _rebuildUri(uri, queryParameters: queryParameters);
    return ParsedPrivateRpcEndpoint(
      safeUrl: safeUri.toString(),
      credential: credential,
      provider: RpcProvider.helius,
      mode: RpcCredentialMode.queryParameter,
      parameter: 'api-key',
    );
  }
  if (host.endsWith('quiknode.pro') && uri.pathSegments.isNotEmpty) {
    return ParsedPrivateRpcEndpoint(
      safeUrl: _rebuildUri(uri, path: '/').toString(),
      credential: value,
      provider: RpcProvider.quickNode,
      mode: RpcCredentialMode.fullEndpoint,
    );
  }
  if (host.endsWith('g.alchemy.com')) {
    return _extractPathCredential(
      uri: uri,
      marker: 'v2',
      provider: RpcProvider.alchemy,
    );
  }
  if (host.endsWith('infura.io')) {
    return _extractPathCredential(
      uri: uri,
      marker: 'v3',
      provider: RpcProvider.infura,
    );
  }
  final genericQueryCredentials = _genericQueryCredentials(uri);
  if (genericQueryCredentials.isNotEmpty) {
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..removeWhere(
        (key, _) => genericQueryCredentials.any((entry) => entry.key == key),
      );
    final safeUrl = _rebuildUri(
      uri,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
    if (genericQueryCredentials.length > 1) {
      return ParsedPrivateRpcEndpoint(
        safeUrl: safeUrl,
        credential: value,
        provider: RpcProvider.custom,
        mode: RpcCredentialMode.fullEndpoint,
      );
    }
    final genericQueryCredential = genericQueryCredentials.single;
    return ParsedPrivateRpcEndpoint(
      safeUrl: safeUrl,
      credential: genericQueryCredential.value,
      provider: RpcProvider.custom,
      mode: RpcCredentialMode.queryParameter,
      parameter: genericQueryCredential.key,
    );
  }
  final lastSegment = uri.pathSegments.lastOrNull;
  if (lastSegment != null &&
      lastSegment.length >= 16 &&
      RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(lastSegment)) {
    return ParsedPrivateRpcEndpoint(
      safeUrl: _rebuildUri(uri, path: '/').toString(),
      credential: value,
      provider: RpcProvider.custom,
      mode: RpcCredentialMode.fullEndpoint,
    );
  }
  return null;
}

List<MapEntry<String, String>> _genericQueryCredentials(Uri uri) {
  const sensitiveNames = {
    'apikey',
    'api_key',
    'api-key',
    'key',
    'token',
    'projectid',
    'project_id',
  };
  return uri.queryParameters.entries
      .where(
        (entry) =>
            sensitiveNames.contains(entry.key.toLowerCase()) &&
            entry.value.isNotEmpty,
      )
      .toList(growable: false);
}

ParsedPrivateRpcEndpoint? _extractPathCredential({
  required Uri uri,
  required String marker,
  required RpcProvider provider,
}) {
  final segments = uri.pathSegments;
  if (segments.length < 2 || segments[segments.length - 2] != marker) {
    return null;
  }
  final credential = segments.last;
  if (credential.isEmpty) {
    return null;
  }
  return ParsedPrivateRpcEndpoint(
    safeUrl: _rebuildUri(
      uri,
      pathSegments: segments.take(segments.length - 1),
    ).toString(),
    credential: credential,
    provider: provider,
    mode: RpcCredentialMode.pathSegment,
  );
}

Uri _rebuildUri(
  Uri uri, {
  String? path,
  Iterable<String>? pathSegments,
  Map<String, String>? queryParameters,
}) {
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: pathSegments == null ? path ?? uri.path : null,
    pathSegments: pathSegments,
    queryParameters: queryParameters,
  );
}

final class ParsedPrivateRpcEndpoint {
  const ParsedPrivateRpcEndpoint({
    required this.safeUrl,
    required this.credential,
    required this.provider,
    required this.mode,
    this.parameter,
  });

  final String safeUrl;
  final String credential;
  final RpcProvider provider;
  final RpcCredentialMode mode;
  final String? parameter;
}
