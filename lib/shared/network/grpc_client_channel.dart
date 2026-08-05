import 'dart:convert';

import 'package:grpc/grpc.dart';

import 'bounded_http_client.dart';

final class DefaultCallOptionsClientChannel extends ClientChannel {
  DefaultCallOptionsClientChannel(
    super.host, {
    super.port = 443,
    Map<String, String> headers = const {},
    Duration requestTimeout = defaultNetworkRequestTimeout,
    ChannelCredentials credentials = const ChannelCredentials.secure(),
    ClientChannel? delegate,
  }) : assert(!requestTimeout.isNegative && requestTimeout != Duration.zero),
       _delegate = delegate,
       _defaultCallOptions = CallOptions(
         metadata: headers,
         timeout: requestTimeout,
       ),
       super(
         options: ChannelOptions(
           credentials: credentials,
           connectTimeout: requestTimeout,
         ),
       );

  final ClientChannel? _delegate;
  final CallOptions _defaultCallOptions;

  @override
  ClientCall<Q, R> createCall<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
  ) {
    final effectiveOptions = _defaultCallOptions.mergedWith(options);
    final delegate = _delegate;
    if (delegate != null) {
      return delegate.createCall<Q, R>(method, requests, effectiveOptions);
    }
    return super.createCall<Q, R>(method, requests, effectiveOptions);
  }

  @override
  Stream<ConnectionState> get onConnectionStateChanged =>
      _delegate?.onConnectionStateChanged ?? super.onConnectionStateChanged;

  @override
  Future<void> shutdown() => _delegate?.shutdown() ?? super.shutdown();

  @override
  Future<void> terminate() => _delegate?.terminate() ?? super.terminate();
}

String grpcClientCacheKey(String rpcUrl, Map<String, String> headers) {
  final entries = headers.entries.toList(growable: false)
    ..sort((left, right) => left.key.compareTo(right.key));
  return jsonEncode([
    rpcUrl,
    for (final entry in entries) [entry.key, entry.value],
  ]);
}
