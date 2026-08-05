import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/crypto/encrypted_payload.dart';
import 'package:safe_wallet/shared/crypto/encrypted_payload_codec.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';

void main() {
  const codec = EncryptedPayloadCodec();

  test('accepts only the supported password payload envelope', () {
    final payload = codec.fromJson(_validJson());

    expect(payload.version, WalletCryptoService.payloadVersion);
    expect(payload.algorithm, 'AES-256-GCM');
    expect(payload.kdf, KdfService.algorithm);
    expect(payload.salt, hasLength(16));
    expect(payload.nonce, hasLength(12));
    expect(payload.authTag, hasLength(16));
  });

  test('rejects unsupported versions, algorithms, and KDF work factors', () {
    for (final mutation in <void Function(Map<String, Object?>)>[
      (json) => json['version'] = 2,
      (json) => json['algorithm'] = 'AES-CBC',
      (json) => json['kdf'] = 'scrypt',
      (json) => json['kdfParams'] = {
        'iterations': EncryptedPayloadCodec.maximumPbkdf2Iterations + 1,
        'bits': 256,
        'saltLength': 16,
      },
    ]) {
      final json = _validJson();
      mutation(json);
      expect(() => codec.fromJson(json), throwsFormatException);
    }
  });

  test('rejects malformed cryptographic field lengths before decryption', () {
    for (final entry in <MapEntry<String, List<int>>>[
      const MapEntry('salt', [1]),
      const MapEntry('nonce', [1]),
      const MapEntry('authTag', [1]),
      const MapEntry('ciphertext', []),
    ]) {
      final json = _validJson()..[entry.key] = base64Encode(entry.value);
      expect(() => codec.fromJson(json), throwsFormatException);
    }
  });

  test('rejects an oversized ciphertext before Base64 decoding it', () {
    final json = _validJson()
      ..['ciphertext'] =
          'A' * (EncryptedPayloadCodec.maximumCiphertextBase64Length + 4);

    expect(() => codec.fromJson(json), throwsFormatException);
  });

  test('decrypt rejects a directly constructed unsupported payload', () async {
    final service = WalletCryptoService(
      kdfService: const KdfService(iterations: 1000),
    );
    final payload = EncryptedPayload(
      version: 1,
      algorithm: 'AES-CBC',
      kdf: KdfService.algorithm,
      kdfParams: const {'iterations': 1000, 'bits': 256, 'saltLength': 16},
      salt: List<int>.filled(16, 1),
      nonce: List<int>.filled(12, 2),
      ciphertext: const [3],
      authTag: List<int>.filled(16, 4),
      createdAt: DateTime.utc(2026),
    );

    await expectLater(
      service.decryptWithPassword(payload: payload, password: 'password'),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _validJson() {
  return {
    'version': 1,
    'algorithm': 'AES-256-GCM',
    'kdf': 'PBKDF2-HMAC-SHA256',
    'kdfParams': const {'iterations': 1000, 'bits': 256, 'saltLength': 16},
    'salt': base64Encode(List<int>.filled(16, 1)),
    'nonce': base64Encode(List<int>.filled(12, 2)),
    'ciphertext': base64Encode(const [3]),
    'authTag': base64Encode(List<int>.filled(16, 4)),
    'createdAt': DateTime.utc(2026).toIso8601String(),
  };
}
