import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart'
    show FlutterError, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

final class KdfService {
  const KdfService({this.iterations = 600000, this.bits = 256});

  static const algorithm = 'PBKDF2-HMAC-SHA256';
  static const saltLength = 16;
  static const minimumIterations = 1;
  static const maximumIterations = 2000000;
  static const supportedBits = 256;
  static const maximumSaltLength = 64;
  static const _nativeChannel = MethodChannel('safe_wallet/crypto');

  final int iterations;
  final int bits;

  Map<String, Object?> get params {
    return {'iterations': iterations, 'bits': bits, 'saltLength': saltLength};
  }

  List<int> newSalt() {
    return SecretKeyData.random(length: saltLength).bytes;
  }

  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
    Map<String, Object?>? params,
  }) async {
    final rawIterations = params?['iterations'];
    final rawBits = params?['bits'];
    if (rawIterations != null && rawIterations is! int ||
        rawBits != null && rawBits is! int) {
      throw ArgumentError('PBKDF2 parameters must be integers');
    }
    final resolvedIterations = rawIterations as int? ?? iterations;
    final resolvedBits = rawBits as int? ?? bits;
    if (resolvedIterations < minimumIterations ||
        resolvedIterations > maximumIterations) {
      throw ArgumentError.value(
        resolvedIterations,
        'iterations',
        'must be between $minimumIterations and $maximumIterations',
      );
    }
    if (resolvedBits != supportedBits) {
      throw ArgumentError.value(resolvedBits, 'bits', 'must be $supportedBits');
    }
    if (salt.isEmpty || salt.length > maximumSaltLength) {
      throw ArgumentError.value(
        salt.length,
        'salt',
        'must contain 1 to $maximumSaltLength bytes',
      );
    }
    final nativeKey = await _deriveWithNativePlatform(
      password: password,
      salt: salt,
      iterations: resolvedIterations,
      bits: resolvedBits,
    );
    if (nativeKey != null) {
      return nativeKey;
    }
    if (!kIsWeb) {
      final isolatedSalt = List<int>.from(salt);
      return Isolate.run(
        () => _deriveWithoutPauses(
          password: password,
          salt: isolatedSalt,
          iterations: resolvedIterations,
          bits: resolvedBits,
        ),
        debugName: 'safe-wallet-pbkdf2',
      );
    }
    final pbkdf2 = Pbkdf2.hmacSha256(
      iterations: resolvedIterations,
      bits: resolvedBits,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<List<int>?> _deriveWithNativePlatform({
    required String password,
    required List<int> salt,
    required int iterations,
    required int bits,
  }) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    try {
      final result = await _nativeChannel
          .invokeMethod<Uint8List>('derivePbkdf2HmacSha256', {
            'password': password,
            'salt': Uint8List.fromList(salt),
            'iterations': iterations,
            'bits': bits,
          });
      if (result != null && result.length == (bits + 7) ~/ 8) {
        return result;
      }
    } on MissingPluginException {
      // Fall back to the isolated Dart implementation.
    } on PlatformException {
      // Fall back to the isolated Dart implementation.
    } on StateError {
      // ServicesBinding is unavailable in pure Dart or uninitialized tests.
    } on FlutterError {
      // ServicesBinding is unavailable in pure Dart or uninitialized tests.
    }
    return null;
  }
}

Future<List<int>> _deriveWithoutPauses({
  required String password,
  required List<int> salt,
  required int iterations,
  required int bits,
}) async {
  final pbkdf2 = DartPbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: bits,
    pausePeriod: Duration.zero,
  );
  final key = await pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );
  return key.extractBytes();
}
