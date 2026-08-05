import 'package:grpc/grpc.dart';
import 'package:sui_dart/grpc/sui_grpc_client.dart' as sdk;

import '../../../shared/chain_clients/sui_json_rpc_client.dart';
import '../../../shared/errors/rpc_error.dart';
import '../../../shared/network/grpc_client_channel.dart';

const suiNativeCoinType = '0x2::sui::SUI';

bool isSuiNativeCoinType(String coinType) {
  final parts = coinType.trim().split('::');
  if (parts.length != 3 || parts[1] != 'sui' || parts[2] != 'SUI') {
    return false;
  }
  final package = parts.first.toLowerCase();
  if (!package.startsWith('0x')) {
    return false;
  }
  final normalized = package.substring(2).replaceFirst(RegExp(r'^0+'), '');
  return normalized == '2';
}

final class SuiCoinBalance {
  const SuiCoinBalance({
    required this.coinType,
    required this.coinObjectCount,
    required this.totalBalance,
  });

  final String coinType;
  final int coinObjectCount;
  final BigInt totalBalance;
}

final class SuiCoinMetadata {
  const SuiCoinMetadata({
    required this.decimals,
    required this.name,
    required this.symbol,
    this.description,
    this.iconUrl,
  });

  final int decimals;
  final String name;
  final String symbol;
  final String? description;
  final String? iconUrl;
}

abstract interface class SuiAssetService {
  Future<SuiCoinBalance> getBalance({
    required String rpcUrl,
    required String owner,
    String coinType = suiNativeCoinType,
    Map<String, String> headers = const {},
  });

  Future<List<SuiCoinBalance>> getAllBalances({
    required String rpcUrl,
    required String owner,
    Map<String, String> headers = const {},
  });

  Future<SuiCoinMetadata?> getCoinMetadata({
    required String rpcUrl,
    required String coinType,
    Map<String, String> headers = const {},
  });
}

typedef SuiGrpcClientBuilder =
    sdk.SuiGrpcClient Function(sdk.SuiGrpcClientOptions options);

final class GrpcSuiAssetService implements SuiAssetService {
  GrpcSuiAssetService({SuiGrpcClientBuilder? clientFactory})
    : _clientFactory = clientFactory ?? sdk.SuiGrpcClient.new;

  final SuiGrpcClientBuilder _clientFactory;
  final Map<String, sdk.SuiGrpcClient> _clients = {};

  @override
  Future<SuiCoinBalance> getBalance({
    required String rpcUrl,
    required String owner,
    String coinType = suiNativeCoinType,
    Map<String, String> headers = const {},
  }) async {
    try {
      final balance = await _clientFor(
        rpcUrl,
        headers,
      ).getBalance(owner, coinType: coinType);
      return _balanceFromGrpc(balance);
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    }
  }

  @override
  Future<List<SuiCoinBalance>> getAllBalances({
    required String rpcUrl,
    required String owner,
    Map<String, String> headers = const {},
  }) async {
    try {
      final balances = await _clientFor(rpcUrl, headers).getAllBalances(owner);
      return balances.map(_balanceFromGrpc).toList(growable: false);
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    }
  }

  @override
  Future<SuiCoinMetadata?> getCoinMetadata({
    required String rpcUrl,
    required String coinType,
    Map<String, String> headers = const {},
  }) async {
    try {
      final metadata = await _clientFor(
        rpcUrl,
        headers,
      ).getCoinMetadata(coinType);
      if (metadata == null) {
        return null;
      }
      return SuiCoinMetadata(
        decimals: metadata.decimals,
        name: metadata.name,
        symbol: metadata.symbol,
        description: metadata.description,
        iconUrl: _safeRemoteUrl(metadata.iconUrl),
      );
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    }
  }

  sdk.SuiGrpcClient _clientFor(String rpcUrl, Map<String, String> headers) {
    final cacheKey = grpcClientCacheKey(rpcUrl, headers);
    return _clients.putIfAbsent(cacheKey, () {
      final endpoint = _parseGrpcEndpoint(rpcUrl);
      return _clientFactory(
        sdk.SuiGrpcClientOptions(
          baseUrl: endpoint.host,
          port: endpoint.port,
          customChannel: DefaultCallOptionsClientChannel(
            endpoint.host,
            port: endpoint.port,
            headers: headers,
          ),
        ),
      );
    });
  }

  Future<void> close() async {
    final clients = _clients.values.toList(growable: false);
    _clients.clear();
    for (final client in clients) {
      await client.shutdown();
    }
  }
}

final class HttpSuiAssetService implements SuiAssetService {
  HttpSuiAssetService({SuiJsonRpcClient? rpcClient})
    : _rpcClient = rpcClient ?? HttpSuiJsonRpcClient(),
      _ownsRpcClient = rpcClient == null;

  final SuiJsonRpcClient _rpcClient;
  final bool _ownsRpcClient;

  @override
  Future<SuiCoinBalance> getBalance({
    required String rpcUrl,
    required String owner,
    String coinType = suiNativeCoinType,
    Map<String, String> headers = const {},
  }) async {
    final result = await _rpcClient.call(
      rpcUrl: rpcUrl,
      method: 'suix_getBalance',
      params: [owner, coinType],
      headers: headers,
    );
    return _parseBalance(result);
  }

  @override
  Future<List<SuiCoinBalance>> getAllBalances({
    required String rpcUrl,
    required String owner,
    Map<String, String> headers = const {},
  }) async {
    final result = await _rpcClient.call(
      rpcUrl: rpcUrl,
      method: 'suix_getAllBalances',
      params: [owner],
      headers: headers,
    );
    if (result is! List) {
      throw const RpcError.unavailable(
        debugMessage: 'Sui all balances result is invalid',
      );
    }
    return result.map(_parseBalance).toList(growable: false);
  }

  @override
  Future<SuiCoinMetadata?> getCoinMetadata({
    required String rpcUrl,
    required String coinType,
    Map<String, String> headers = const {},
  }) async {
    final result = await _rpcClient.call(
      rpcUrl: rpcUrl,
      method: 'suix_getCoinMetadata',
      params: [coinType],
      headers: headers,
    );
    if (result == null) {
      return null;
    }
    if (result is! Map) {
      throw const RpcError.unavailable(
        debugMessage: 'Sui Coin metadata result is invalid',
      );
    }
    final decimals = result['decimals'];
    final name = result['name'];
    final symbol = result['symbol'];
    if (decimals is! num ||
        decimals < 0 ||
        decimals > 255 ||
        name is! String ||
        name.trim().isEmpty ||
        symbol is! String ||
        symbol.trim().isEmpty) {
      throw const RpcError.unavailable(
        debugMessage: 'Sui Coin metadata fields are invalid',
      );
    }
    return SuiCoinMetadata(
      decimals: decimals.toInt(),
      name: name,
      symbol: symbol,
      description: result['description'] is String
          ? result['description'] as String
          : null,
      iconUrl: _safeRemoteUrl(result['iconUrl']),
    );
  }

  void close() {
    if (_ownsRpcClient && _rpcClient is HttpSuiJsonRpcClient) {
      _rpcClient.close();
    }
  }
}

SuiCoinBalance _parseBalance(Object? value) {
  if (value is! Map) {
    throw const RpcError.unavailable(
      debugMessage: 'Sui balance result is invalid',
    );
  }
  final coinType = value['coinType'];
  final count = value['coinObjectCount'];
  final totalBalance = value['totalBalance'];
  final parsedCount = switch (count) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
  final parsedBalance = totalBalance is String
      ? BigInt.tryParse(totalBalance)
      : totalBalance is num
      ? BigInt.from(totalBalance)
      : null;
  if (coinType is! String ||
      coinType.trim().isEmpty ||
      parsedCount == null ||
      parsedCount < 0 ||
      parsedBalance == null ||
      parsedBalance < BigInt.zero) {
    throw const RpcError.unavailable(
      debugMessage: 'Sui balance fields are invalid',
    );
  }
  return SuiCoinBalance(
    coinType: coinType,
    coinObjectCount: parsedCount,
    totalBalance: parsedBalance,
  );
}

String? _safeRemoteUrl(Object? value) {
  if (value is! String || value.length > 2048) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  return uri.toString();
}

SuiCoinBalance _balanceFromGrpc(sdk.Balance balance) {
  final totalBalance = BigInt.tryParse(balance.balance);
  if (balance.coinType.isEmpty ||
      totalBalance == null ||
      totalBalance < BigInt.zero) {
    throw const RpcError.unavailable(
      debugMessage: 'Sui gRPC balance fields are invalid',
    );
  }
  return SuiCoinBalance(
    coinType: balance.coinType,
    coinObjectCount: 0,
    totalBalance: totalBalance,
  );
}

({String host, int port}) _parseGrpcEndpoint(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.scheme != 'https' ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const RpcError.invalidUrl();
  }
  return (host: uri.host, port: uri.hasPort ? uri.port : 443);
}

RpcError _rpcErrorFromGrpc(GrpcError error) {
  return switch (error.code) {
    StatusCode.unauthenticated ||
    StatusCode.permissionDenied => const RpcError.invalidCredential(),
    StatusCode.resourceExhausted => const RpcError.rateLimited(),
    _ => RpcError.unavailable(
      debugMessage: 'Sui gRPC request failed with code ${error.code}',
    ),
  };
}
