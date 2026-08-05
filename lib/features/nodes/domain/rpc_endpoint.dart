import '../data/rpc_credential_store.dart';
import '../../../shared/errors/rpc_error.dart';
import 'rpc_node.dart';

final class ResolvedRpcEndpoint {
  const ResolvedRpcEndpoint({required this.uri, this.headers = const {}});

  final Uri uri;
  final Map<String, String> headers;

  String get url => uri.toString();
}

final class RpcEndpointResolver {
  const RpcEndpointResolver({required RpcCredentialStore credentialStore})
    : _credentialStore = credentialStore;

  final RpcCredentialStore _credentialStore;

  Future<ResolvedRpcEndpoint> resolve(RpcNode node) async {
    if (node.credentialMode == RpcCredentialMode.none) {
      return _resolveWithCredential(node, null);
    }

    final credentialRef = node.credentialRef;
    if (credentialRef == null || credentialRef.isEmpty) {
      throw const RpcError.missingCredential();
    }
    final credential = await _credentialStore.read(credentialRef);
    if (credential == null || credential.isEmpty) {
      throw const RpcError.missingCredential();
    }

    return _resolveWithCredential(node, credential);
  }

  ResolvedRpcEndpoint resolveWithCredential(RpcNode node, String credential) {
    if (credential.trim().isEmpty) {
      throw const RpcError.missingCredential();
    }
    return _resolveWithCredential(node, credential.trim());
  }

  ResolvedRpcEndpoint _resolveWithCredential(RpcNode node, String? credential) {
    final baseUri = _parseUri(node.url);
    return switch (node.credentialMode) {
      RpcCredentialMode.none => ResolvedRpcEndpoint(uri: baseUri),
      RpcCredentialMode.queryParameter => ResolvedRpcEndpoint(
        uri: _withQueryCredential(node, baseUri, credential!),
      ),
      RpcCredentialMode.pathSegment => ResolvedRpcEndpoint(
        uri: _withPathCredential(baseUri, credential!),
      ),
      RpcCredentialMode.header => ResolvedRpcEndpoint(
        uri: baseUri,
        headers: {_requiredParameter(node): credential!},
      ),
      RpcCredentialMode.fullEndpoint => ResolvedRpcEndpoint(
        uri: _parseUri(credential!),
      ),
    };
  }

  Uri _withQueryCredential(RpcNode node, Uri baseUri, String credential) {
    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        _requiredParameter(node): credential,
      },
    );
  }

  Uri _withPathCredential(Uri baseUri, String credential) {
    return baseUri.replace(pathSegments: [...baseUri.pathSegments, credential]);
  }

  String _requiredParameter(RpcNode node) {
    final parameter = node.credentialParameter;
    if (parameter == null || parameter.isEmpty) {
      throw StateError('RPC credential parameter is missing');
    }
    return parameter;
  }
}

extension RpcNodeDisplay on RpcNode {
  String get displayUrl {
    final uri = _parseUri(url);
    return switch (credentialMode) {
      RpcCredentialMode.none || RpcCredentialMode.header => uri.toString(),
      RpcCredentialMode.queryParameter => _displayQueryUrl(uri),
      RpcCredentialMode.pathSegment => _displayPathUrl(uri),
      RpcCredentialMode.fullEndpoint => _displayFullEndpoint(uri),
    };
  }

  String _displayQueryUrl(Uri uri) {
    final parameter = credentialParameter;
    if (parameter == null || parameter.isEmpty) {
      return uri.toString();
    }
    final separator = uri.hasQuery ? '&' : '?';
    return '${uri.toString()}$separator$parameter=••••••••';
  }

  String _displayFullEndpoint(Uri uri) {
    return '${uri.scheme}://${uri.authority}/••••••••';
  }

  String _displayPathUrl(Uri uri) {
    final base = uri.replace(query: null, fragment: null).toString();
    final separator = uri.path.endsWith('/') ? '' : '/';
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$base$separator••••••••$query$fragment';
  }
}

Uri _parseUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' &&
          !(uri.scheme == 'http' && _isLoopbackHost(uri.host)))) {
    throw StateError('RPC URL is invalid');
  }
  return uri;
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
