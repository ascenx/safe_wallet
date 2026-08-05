import 'package:hive_ce/hive.dart';

import 'storage_keys.dart';

final class HiveBoxRegistry {
  const HiveBoxRegistry(this._boxes);

  final Map<String, Box<dynamic>> _boxes;

  Box<dynamic> get walletsBox => box(StorageKeys.walletsBox);
  Box<dynamic> get chainsBox => box(StorageKeys.chainsBox);
  Box<dynamic> get rpcNodesBox => box(StorageKeys.rpcNodesBox);
  Box<dynamic> get tokensBox => box(StorageKeys.tokensBox);
  Box<dynamic> get tokenPricesBox => box(StorageKeys.tokenPricesBox);
  Box<dynamic> get tokenBalancesBox => box(StorageKeys.tokenBalancesBox);
  Box<dynamic> get transactionsBox => box(StorageKeys.transactionsBox);
  Box<dynamic> get dappPermissionsBox => box(StorageKeys.dappPermissionsBox);
  Box<dynamic> get dappCatalogBox => box(StorageKeys.dappCatalogBox);
  Box<dynamic> get browserStateBox => box(StorageKeys.browserStateBox);
  Box<dynamic> get addressBookBox => box(StorageKeys.addressBookBox);
  Box<dynamic> get securityLogsBox => box(StorageKeys.securityLogsBox);
  Box<dynamic> get settingsBox => box(StorageKeys.settingsBox);

  bool isOpen(String name) {
    return _boxes[name]?.isOpen ?? false;
  }

  Box<dynamic> box(String name) {
    final openedBox = _boxes[name];
    if (openedBox == null) {
      throw StateError('Hive box is not registered: $name');
    }
    return openedBox;
  }
}
