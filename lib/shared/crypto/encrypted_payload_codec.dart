import 'dart:convert';

import 'aes_gcm_service.dart';
import 'encrypted_payload.dart';
import 'kdf_service.dart';

final class EncryptedPayloadCodec {
  const EncryptedPayloadCodec();

  static const maximumCiphertextBytes = 1024 * 1024;
  static const supportedPayloadVersion = 1;
  static const maximumCiphertextBase64Length =
      ((maximumCiphertextBytes + 2) ~/ 3) * 4;
  static const maximumPbkdf2Iterations = KdfService.maximumIterations;

  Map<String, Object?> toJson(EncryptedPayload payload) {
    validate(payload);
    return {
      'version': payload.version,
      'algorithm': payload.algorithm,
      'kdf': payload.kdf,
      'kdfParams': payload.kdfParams,
      'salt': base64Encode(payload.salt),
      'nonce': base64Encode(payload.nonce),
      'ciphertext': base64Encode(payload.ciphertext),
      'authTag': base64Encode(payload.authTag),
      'createdAt': payload.createdAt.toIso8601String(),
    };
  }

  EncryptedPayload fromJson(Map<dynamic, dynamic> json) {
    final version = json['version'];
    final algorithm = json['algorithm'];
    final kdf = json['kdf'];
    final rawKdfParams = json['kdfParams'];
    final createdAtValue = json['createdAt'];
    if (version is! int ||
        algorithm is! String ||
        kdf is! String ||
        rawKdfParams is! Map ||
        createdAtValue is! String ||
        createdAtValue.length > 64) {
      throw const FormatException('Encrypted payload envelope is invalid');
    }
    final kdfParams = <String, Object?>{};
    for (final entry in rawKdfParams.entries) {
      if (entry.key is! String || kdfParams.length >= 8) {
        throw const FormatException('Encrypted payload KDF params are invalid');
      }
      kdfParams[entry.key as String] = entry.value;
    }
    final createdAt = DateTime.tryParse(createdAtValue);
    if (createdAt == null) {
      throw const FormatException('Encrypted payload timestamp is invalid');
    }
    final payload = EncryptedPayload(
      version: version,
      algorithm: algorithm,
      kdf: kdf,
      kdfParams: kdfParams,
      salt: _decodeBytes(json, 'salt', maximumEncodedLength: 128),
      nonce: _decodeBytes(json, 'nonce', maximumEncodedLength: 128),
      ciphertext: _decodeBytes(
        json,
        'ciphertext',
        maximumEncodedLength: maximumCiphertextBase64Length,
      ),
      authTag: _decodeBytes(json, 'authTag', maximumEncodedLength: 128),
      createdAt: createdAt,
    );
    validate(payload);
    return payload;
  }

  static void validate(
    EncryptedPayload payload, {
    bool requirePasswordKdf = false,
  }) {
    if (payload.version != supportedPayloadVersion ||
        payload.algorithm != AesGcmService.algorithmName ||
        payload.nonce.length != 12 ||
        payload.authTag.length != 16 ||
        payload.ciphertext.isEmpty ||
        payload.ciphertext.length > maximumCiphertextBytes ||
        !_validBytes(payload.nonce) ||
        !_validBytes(payload.authTag) ||
        !_validBytes(payload.ciphertext) ||
        !_validBytes(payload.salt)) {
      throw const FormatException('Encrypted payload parameters are invalid');
    }

    if (payload.kdf == KdfService.algorithm) {
      final iterations = payload.kdfParams['iterations'];
      final bits = payload.kdfParams['bits'];
      final saltLength = payload.kdfParams['saltLength'];
      if (payload.kdfParams.length != 3 ||
          iterations is! int ||
          iterations < KdfService.minimumIterations ||
          iterations > KdfService.maximumIterations ||
          bits != KdfService.supportedBits ||
          saltLength != KdfService.saltLength ||
          payload.salt.length != KdfService.saltLength) {
        throw const FormatException('Encrypted payload KDF is invalid');
      }
      return;
    }

    if (!requirePasswordKdf &&
        payload.kdf == 'none' &&
        payload.kdfParams.isEmpty &&
        payload.salt.isEmpty) {
      return;
    }
    throw const FormatException('Encrypted payload KDF is unsupported');
  }

  List<int> _decodeBytes(
    Map<dynamic, dynamic> json,
    String field, {
    required int maximumEncodedLength,
  }) {
    final value = json[field];
    if (value is! String || value.length > maximumEncodedLength) {
      throw FormatException('Encrypted payload $field is invalid');
    }
    try {
      return base64Decode(value);
    } on FormatException {
      throw FormatException('Encrypted payload $field is invalid');
    }
  }

  static bool _validBytes(List<int> values) =>
      values.every((value) => value >= 0 && value <= 255);
}
