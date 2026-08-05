import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../domain/wallet_connect_models.dart';

const _defaultWalletConnectIconLimit = 256 * 1024;
const _defaultWalletConnectIconTimeout = Duration(seconds: 5);

Uri? walletConnectPeerIconUri(WalletConnectPeerMetadata peer) {
  for (final value in peer.icons) {
    if (value.length > 2048) {
      continue;
    }
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        _isPublicIconHost(uri.host)) {
      return uri;
    }
  }
  return null;
}

final class WalletConnectPeerAvatar extends StatefulWidget {
  const WalletConnectPeerAvatar({
    required this.peer,
    this.radius = 20,
    this.client,
    this.maxImageBytes = _defaultWalletConnectIconLimit,
    this.requestTimeout = _defaultWalletConnectIconTimeout,
    super.key,
  }) : assert(maxImageBytes > 0);

  final WalletConnectPeerMetadata peer;
  final double radius;
  final http.Client? client;
  final int maxImageBytes;
  final Duration requestTimeout;

  @override
  State<WalletConnectPeerAvatar> createState() =>
      _WalletConnectPeerAvatarState();
}

final class _WalletConnectPeerAvatarState
    extends State<WalletConnectPeerAvatar> {
  late http.Client _client;
  late bool _ownsClient;
  late Future<Uint8List?> _imageBytes;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(WalletConnectPeerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.peer.icons != widget.peer.icons ||
        oldWidget.maxImageBytes != widget.maxImageBytes ||
        oldWidget.requestTimeout != widget.requestTimeout) {
      if (_ownsClient) {
        _client.close();
      }
      _configure();
    }
  }

  void _configure() {
    _ownsClient = widget.client == null;
    _client =
        widget.client ??
        BoundedHttpClient(
          requestTimeout: widget.requestTimeout,
          maxResponseBytes: widget.maxImageBytes,
        );
    _imageBytes = _loadImageBytes();
  }

  Future<Uint8List?> _loadImageBytes() async {
    final uri = walletConnectPeerIconUri(widget.peer);
    if (uri == null) {
      return null;
    }
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['accept'] = 'image/png,image/jpeg,image/webp,image/gif';
      final response = await _client
          .send(request)
          .timeout(widget.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final contentType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (contentType == null ||
          !const {
            'image/png',
            'image/jpeg',
            'image/webp',
            'image/gif',
          }.contains(contentType)) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > widget.maxImageBytes) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream.timeout(
        widget.requestTimeout,
      )) {
        received += chunk.length;
        if (received > widget.maxImageBytes) {
          return null;
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackText(widget.peer.name);
    return CircleAvatar(
      radius: widget.radius,
      child: ClipOval(
        child: FutureBuilder<Uint8List?>(
          future: _imageBytes,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes == null) {
              return Center(child: Text(fallback));
            }
            final pixelSize =
                (widget.radius * 2 * MediaQuery.devicePixelRatioOf(context))
                    .ceil();
            return Image.memory(
              bytes,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              cacheWidth: pixelSize,
              cacheHeight: pixelSize,
              errorBuilder: (context, error, stackTrace) =>
                  Center(child: Text(fallback)),
            );
          },
        ),
      ),
    );
  }
}

bool _isPublicIconHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.local') ||
      normalized.endsWith('.internal') ||
      normalized.endsWith('.lan') ||
      normalized.contains(':')) {
    return false;
  }
  final ipv4Parts = normalized.split('.');
  if (ipv4Parts.length == 4 &&
      ipv4Parts.every((part) {
        final value = int.tryParse(part);
        return value != null && value >= 0 && value <= 255;
      })) {
    return false;
  }
  return true;
}

String _fallbackText(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first;
}
