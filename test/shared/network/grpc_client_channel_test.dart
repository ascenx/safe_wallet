import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:safe_wallet/shared/network/bounded_http_client.dart';
import 'package:safe_wallet/shared/network/grpc_client_channel.dart';

void main() {
  test('adds default metadata and request timeout to every gRPC call', () {
    final delegate = _RecordingClientChannel();
    final channel = DefaultCallOptionsClientChannel(
      'rpc.example',
      headers: const {'authorization': 'Bearer default', 'x-api-key': 'key'},
      delegate: delegate,
    );
    final method = ClientMethod<String, String>(
      '/test.Service/Method',
      (value) => value.codeUnits,
      String.fromCharCodes,
    );

    expect(
      () => channel.createCall(
        method,
        const Stream<String>.empty(),
        CallOptions(
          metadata: const {
            'authorization': 'Bearer override',
            'x-request-id': 'request',
          },
          timeout: const Duration(seconds: 3),
        ),
      ),
      throwsStateError,
    );

    expect(delegate.lastOptions?.metadata, {
      'authorization': 'Bearer override',
      'x-api-key': 'key',
      'x-request-id': 'request',
    });
    expect(delegate.lastOptions?.timeout, const Duration(seconds: 3));
  });

  test('sets bounded connect and request timeouts by default', () {
    final channel = DefaultCallOptionsClientChannel('rpc.example');

    expect(channel.options.connectTimeout, defaultNetworkRequestTimeout);

    final delegate = _RecordingClientChannel();
    final wrapped = DefaultCallOptionsClientChannel(
      'rpc.example',
      delegate: delegate,
    );
    final method = ClientMethod<String, String>(
      '/test.Service/Method',
      (value) => value.codeUnits,
      String.fromCharCodes,
    );
    expect(
      () => wrapped.createCall(
        method,
        const Stream<String>.empty(),
        CallOptions(),
      ),
      throwsStateError,
    );
    expect(delegate.lastOptions?.timeout, defaultNetworkRequestTimeout);
  });

  test(
    'gRPC client cache key is stable by header order and isolates values',
    () {
      final first = grpcClientCacheKey('https://rpc.example', const {
        'x-api-key': 'one',
        'authorization': 'Bearer token',
      });
      final reordered = grpcClientCacheKey('https://rpc.example', const {
        'authorization': 'Bearer token',
        'x-api-key': 'one',
      });
      final differentCredential = grpcClientCacheKey(
        'https://rpc.example',
        const {'authorization': 'Bearer other', 'x-api-key': 'one'},
      );

      expect(reordered, first);
      expect(differentCredential, isNot(first));
    },
  );
}

final class _RecordingClientChannel extends ClientChannel {
  _RecordingClientChannel()
    : super(
        'localhost',
        port: 1,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

  CallOptions? lastOptions;

  @override
  ClientCall<Q, R> createCall<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
  ) {
    lastOptions = options;
    throw StateError('recorded');
  }
}
