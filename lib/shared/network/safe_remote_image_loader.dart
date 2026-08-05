import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const defaultRemoteImageLimit = 512 * 1024;
const defaultRemoteImageTimeout = Duration(seconds: 5);

typedef RemoteHostLookup = Future<List<InternetAddress>> Function(String host);

final class SafeRemoteImageData {
  const SafeRemoteImageData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  bool get isSvg => mimeType == 'image/svg+xml';
}

Uri? safeRemoteImageUri(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty || normalized.length > 2048) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443) ||
      !_isPotentiallyPublicHost(uri.host)) {
    return null;
  }
  return uri;
}

final class SafeRemoteImageLoader {
  SafeRemoteImageLoader({
    http.Client? client,
    RemoteHostLookup? lookup,
    this.maxImageBytes = defaultRemoteImageLimit,
    this.requestTimeout = defaultRemoteImageTimeout,
  }) : assert(maxImageBytes > 0),
       assert(!requestTimeout.isNegative && requestTimeout != Duration.zero),
       _lookup = lookup ?? InternetAddress.lookup {
    _client =
        client ??
        _buildPinnedHttpClient(_lookup, requestTimeout: requestTimeout);
  }

  static final shared = SafeRemoteImageLoader();

  late final http.Client _client;
  final RemoteHostLookup _lookup;
  final int maxImageBytes;
  final Duration requestTimeout;

  Future<SafeRemoteImageData?> load(String value) async {
    final uri = safeRemoteImageUri(value);
    if (uri == null || !await _resolvesOnlyToPublicAddresses(uri.host)) {
      return null;
    }
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['accept'] =
            'image/png,image/jpeg,image/webp,image/gif,image/svg+xml';
      final response = await _client.send(request).timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final mimeType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (mimeType == null || !_allowedImageMimeTypes.contains(mimeType)) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > maxImageBytes) {
        await response.stream.listen(null).cancel();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream.timeout(requestTimeout)) {
        received += chunk.length;
        if (received > maxImageBytes) {
          return null;
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return SafeRemoteImageData(bytes: bytes, mimeType: mimeType);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _resolvesOnlyToPublicAddresses(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      return _isPublicInternetAddress(literal);
    }
    try {
      final addresses = await _lookup(host).timeout(requestTimeout);
      return addresses.isNotEmpty && addresses.every(_isPublicInternetAddress);
    } catch (_) {
      return false;
    }
  }
}

http.Client _buildPinnedHttpClient(
  RemoteHostLookup lookup, {
  required Duration requestTimeout,
}) {
  final ioClient = HttpClient()
    ..connectionTimeout = requestTimeout
    ..findProxy = (_) => 'DIRECT';
  ioClient.connectionFactory = (uri, proxyHost, proxyPort) async {
    if (proxyHost != null || proxyPort != null) {
      throw const SocketException('Remote images do not support proxies');
    }
    final literal = InternetAddress.tryParse(uri.host);
    final addresses = literal == null
        ? await lookup(uri.host).timeout(requestTimeout)
        : [literal];
    if (addresses.isEmpty || !addresses.every(_isPublicInternetAddress)) {
      throw const SocketException('Remote image host is not public');
    }
    final address = addresses.firstWhere(
      (value) => value.type == InternetAddressType.IPv4,
      orElse: () => addresses.first,
    );
    final socketTask = await Socket.startConnect(address, uri.port);
    final secureSocket = socketTask.socket.then(
      (socket) => SecureSocket.secure(socket, host: uri.host),
    );
    return ConnectionTask.fromSocket<Socket>(secureSocket, socketTask.cancel);
  };
  return IOClient(ioClient);
}

const _allowedImageMimeTypes = {
  'image/png',
  'image/jpeg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
};

bool _isPotentiallyPublicHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  return normalized.isNotEmpty &&
      normalized != 'localhost' &&
      !normalized.endsWith('.localhost') &&
      !normalized.endsWith('.local') &&
      !normalized.endsWith('.internal') &&
      !normalized.endsWith('.lan');
}

bool _isPublicInternetAddress(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    final first = bytes[0];
    final second = bytes[1];
    return first != 0 &&
        first != 10 &&
        first != 127 &&
        !(first == 100 && second >= 64 && second <= 127) &&
        !(first == 169 && second == 254) &&
        !(first == 172 && second >= 16 && second <= 31) &&
        !(first == 192 && second == 0) &&
        !(first == 192 && second == 168) &&
        !(first == 198 && (second == 18 || second == 19)) &&
        first < 224;
  }
  if (bytes.every((byte) => byte == 0) || address.isLoopback) {
    return false;
  }
  final first = bytes[0];
  final second = bytes[1];
  return first != 0xff &&
      (first & 0xfe) != 0xfc &&
      !(first == 0xfe && (second & 0xc0) == 0x80) &&
      !(bytes[0] == 0x20 &&
          bytes[1] == 0x01 &&
          bytes[2] == 0x0d &&
          bytes[3] == 0xb8);
}
