import 'aes_gcm_service.dart';
import 'encrypted_payload.dart';
import 'encrypted_payload_codec.dart';
import 'kdf_service.dart';

final class WalletCryptoService {
  WalletCryptoService({
    KdfService kdfService = const KdfService(),
    AesGcmService? aesGcmService,
  }) : _kdfService = kdfService,
       _aesGcmService = aesGcmService ?? AesGcmService();

  static const payloadVersion = EncryptedPayloadCodec.supportedPayloadVersion;

  final KdfService _kdfService;
  final AesGcmService _aesGcmService;

  Future<EncryptedPayload> encryptWithPassword({
    required List<int> plaintext,
    required String password,
  }) async {
    final salt = _kdfService.newSalt();
    final kdfParams = _kdfService.params;
    final keyBytes = await _kdfService.deriveKey(
      password: password,
      salt: salt,
      params: kdfParams,
    );
    final encrypted = await _aesGcmService.encrypt(
      plaintext: plaintext,
      keyBytes: keyBytes,
    );

    return EncryptedPayload(
      version: payloadVersion,
      algorithm: AesGcmService.algorithmName,
      kdf: KdfService.algorithm,
      kdfParams: kdfParams,
      salt: salt,
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      authTag: encrypted.authTag,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<List<int>> decryptWithPassword({
    required EncryptedPayload payload,
    required String password,
  }) async {
    EncryptedPayloadCodec.validate(payload, requirePasswordKdf: true);
    final keyBytes = await _kdfService.deriveKey(
      password: password,
      salt: payload.salt,
      params: payload.kdfParams,
    );
    return _aesGcmService.decrypt(
      ciphertext: payload.ciphertext,
      nonce: payload.nonce,
      authTag: payload.authTag,
      keyBytes: keyBytes,
    );
  }
}
