import 'package:cryptography/cryptography.dart';

final class AesGcmEncryptionResult {
  const AesGcmEncryptionResult({
    required this.nonce,
    required this.ciphertext,
    required this.authTag,
  });

  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> authTag;
}

final class AesGcmService {
  AesGcmService({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const algorithmName = 'AES-256-GCM';

  final AesGcm _algorithm;

  Future<AesGcmEncryptionResult> encrypt({
    required List<int> plaintext,
    required List<int> keyBytes,
    List<int> aad = const [],
  }) async {
    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      aad: aad,
    );
    return AesGcmEncryptionResult(
      nonce: secretBox.nonce,
      ciphertext: secretBox.cipherText,
      authTag: secretBox.mac.bytes,
    );
  }

  Future<List<int>> decrypt({
    required List<int> ciphertext,
    required List<int> nonce,
    required List<int> authTag,
    required List<int> keyBytes,
    List<int> aad = const [],
  }) {
    return _algorithm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(authTag)),
      secretKey: SecretKey(keyBytes),
      aad: aad,
    );
  }
}
