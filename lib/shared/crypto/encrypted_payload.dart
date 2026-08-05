final class EncryptedPayload {
  EncryptedPayload({
    required this.version,
    required this.algorithm,
    required this.kdf,
    required Map<String, Object?> kdfParams,
    required List<int> salt,
    required List<int> nonce,
    required List<int> ciphertext,
    required List<int> authTag,
    required this.createdAt,
  })  : kdfParams = Map.unmodifiable(kdfParams),
        salt = List.unmodifiable(salt),
        nonce = List.unmodifiable(nonce),
        ciphertext = List.unmodifiable(ciphertext),
        authTag = List.unmodifiable(authTag);

  final int version;
  final String algorithm;
  final String kdf;
  final Map<String, Object?> kdfParams;
  final List<int> salt;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> authTag;
  final DateTime createdAt;

  EncryptedPayload copyWith({
    int? version,
    String? algorithm,
    String? kdf,
    Map<String, Object?>? kdfParams,
    List<int>? salt,
    List<int>? nonce,
    List<int>? ciphertext,
    List<int>? authTag,
    DateTime? createdAt,
  }) {
    return EncryptedPayload(
      version: version ?? this.version,
      algorithm: algorithm ?? this.algorithm,
      kdf: kdf ?? this.kdf,
      kdfParams: kdfParams ?? this.kdfParams,
      salt: salt ?? this.salt,
      nonce: nonce ?? this.nonce,
      ciphertext: ciphertext ?? this.ciphertext,
      authTag: authTag ?? this.authTag,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
