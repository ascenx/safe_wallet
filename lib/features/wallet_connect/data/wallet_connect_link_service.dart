import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class WalletConnectLinkService {
  Stream<String> get links;
  Future<String?> getInitialUri();
  Future<void> dispose();
}

final walletConnectLinkServiceProvider = Provider<WalletConnectLinkService>((
  ref,
) {
  final service = MethodChannelWalletConnectLinkService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final class MethodChannelWalletConnectLinkService
    implements WalletConnectLinkService {
  MethodChannelWalletConnectLinkService({
    MethodChannel channel = const MethodChannel(
      'safe_wallet/wallet_connect_link',
    ),
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final StreamController<String> _controller = StreamController.broadcast();
  String? _lastUri;

  @override
  Stream<String> get links => _controller.stream;

  @override
  Future<String?> getInitialUri() async {
    try {
      final value = await _channel.invokeMethod<String>('getInitialLink');
      return value == null ? null : walletConnectUriFromLink(value);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onLink') {
      return null;
    }
    final uri = call.arguments is String
        ? walletConnectUriFromLink(call.arguments as String)
        : null;
    if (uri != null && uri != _lastUri && !_controller.isClosed) {
      _lastUri = uri;
      _controller.add(uri);
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _controller.close();
  }
}

String? walletConnectUriFromLink(String value) {
  var candidate = value;
  final uri = Uri.tryParse(value);
  if (uri != null &&
      uri.scheme.toLowerCase() == 'safewallet' &&
      uri.host.toLowerCase() == 'walletconnect') {
    candidate = uri.queryParameters['uri'] ?? '';
  }
  if (candidate.isEmpty ||
      value.length > 8192 ||
      candidate.contains(RegExp(r'\s')) ||
      !RegExp(r'^wc:[^@]{1,256}@2\?.+$').hasMatch(candidate)) {
    return null;
  }
  return candidate;
}
