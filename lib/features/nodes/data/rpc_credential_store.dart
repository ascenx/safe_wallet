import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RpcCredentialStore {
  Future<String?> read(String credentialRef);

  Future<void> write(String credentialRef, String credential);

  Future<void> delete(String credentialRef);
}

final class FlutterSecureRpcCredentialStore implements RpcCredentialStore {
  FlutterSecureRpcCredentialStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'safe_wallet_rpc_credential.';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> read(String credentialRef) {
    return _secureStorage.read(key: _storageKey(credentialRef));
  }

  @override
  Future<void> write(String credentialRef, String credential) {
    return _secureStorage.write(
      key: _storageKey(credentialRef),
      value: credential,
    );
  }

  @override
  Future<void> delete(String credentialRef) {
    return _secureStorage.delete(key: _storageKey(credentialRef));
  }

  String _storageKey(String credentialRef) => '$_keyPrefix$credentialRef';
}
