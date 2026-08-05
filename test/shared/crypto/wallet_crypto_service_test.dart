import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';

void main() {
  group('WalletCryptoService', () {
    final service = WalletCryptoService(
      kdfService: const KdfService(iterations: 1000),
    );

    test('decrypts encrypted wallet material with the same password', () async {
      final plaintext = utf8.encode('seed phrase private material');

      final payload = await service.encryptWithPassword(
        plaintext: plaintext,
        password: 'correct horse battery staple',
      );
      final decrypted = await service.decryptWithPassword(
        payload: payload,
        password: 'correct horse battery staple',
      );

      expect(decrypted, plaintext);
      expect(payload.version, 1);
      expect(payload.algorithm, 'AES-256-GCM');
      expect(payload.kdf, 'PBKDF2-HMAC-SHA256');
      expect(payload.kdfParams['iterations'], 1000);
      expect(payload.salt, hasLength(16));
      expect(payload.nonce, hasLength(12));
      expect(payload.authTag, hasLength(16));
      expect(payload.ciphertext, isNotEmpty);
    });

    test('fails with a wrong password', () async {
      final payload = await service.encryptWithPassword(
        plaintext: utf8.encode('secret'),
        password: 'right-password',
      );

      expect(
        () => service.decryptWithPassword(
          payload: payload,
          password: 'wrong-password',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('fails when ciphertext is tampered', () async {
      final payload = await service.encryptWithPassword(
        plaintext: utf8.encode('secret'),
        password: 'password',
      );
      final tamperedCiphertext = [...payload.ciphertext];
      tamperedCiphertext[0] = tamperedCiphertext[0] ^ 0xFF;

      expect(
        () => service.decryptWithPassword(
          payload: payload.copyWith(ciphertext: tamperedCiphertext),
          password: 'password',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
