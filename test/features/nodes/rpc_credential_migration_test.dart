import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_migration.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/shared/storage/json_codec.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  test('multiple generic query credentials are all removed from the safe URL',
      () {
    const endpoint =
        'https://rpc.example.com/?api-key=first-secret&token=second-secret&network=mainnet';

    final parsed = parsePrivateRpcEndpoint(endpoint);

    expect(parsed, isNotNull);
    expect(parsed!.safeUrl, 'https://rpc.example.com/?network=mainnet');
    expect(parsed.credential, endpoint);
    expect(parsed.provider, RpcProvider.custom);
    expect(parsed.mode, RpcCredentialMode.fullEndpoint);
    expect(parsed.safeUrl, isNot(contains('first-secret')));
    expect(parsed.safeUrl, isNot(contains('second-secret')));
  });

  test('known private URLs are removed from node and chain Hive records',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('rpc_credential_migration_');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    final registry =
        await StorageInitializer(path: directory.path).initialize();
    const codec = StorageJsonCodec();
    const privateUrl = 'https://mainnet.helius-rpc.com/?api-key=legacy-secret';
    await registry.rpcNodesBox.put(
      'solana-mainnet-default-0',
      codec.encode({
        'id': 'solana-mainnet-default-0',
        'chainId': 'mainnet-beta',
        'name': 'Solana Mainnet Default',
        'url': privateUrl,
        'nodeType': 'defaultNode',
        'isSelected': true,
        'lastTestStatus': 'untested',
      }),
    );
    await registry.chainsBox.put(
      'solana-mainnet',
      codec.encode({
        'id': 'solana-mainnet',
        'chainType': 'solana',
        'name': 'Solana Mainnet',
        'chainId': 'mainnet-beta',
        'symbol': 'SOL',
        'rpcUrls': [privateUrl],
        'blockExplorerUrl': 'https://explorer.solana.com',
        'isTestnet': false,
      }),
    );
    final credentials = _MemoryRpcCredentialStore();

    await RpcCredentialMigration(
      registry: registry,
      credentialStore: credentials,
    ).apply();

    final node = codec.decode(
      registry.rpcNodesBox.get('solana-mainnet-default-0') as String,
    );
    final chain = codec.decode(
      registry.chainsBox.get('solana-mainnet') as String,
    );
    expect(node['url'], 'https://mainnet.helius-rpc.com/');
    expect(node['provider'], 'helius');
    expect(node['credentialMode'], 'queryParameter');
    expect(node['credentialRef'], 'rpc-node.solana-mainnet-default-0');
    expect(chain['rpcUrls'], ['https://mainnet.helius-rpc.com/']);
    expect(
      await credentials.read('rpc-node.solana-mainnet-default-0'),
      'legacy-secret',
    );
    expect(
        registry.rpcNodesBox.values.join(), isNot(contains('legacy-secret')));
    expect(registry.chainsBox.values.join(), isNot(contains('legacy-secret')));
  });
}

final class _MemoryRpcCredentialStore implements RpcCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String credentialRef) async =>
      values.remove(credentialRef);

  @override
  Future<String?> read(String credentialRef) async => values[credentialRef];

  @override
  Future<void> write(String credentialRef, String credential) async {
    values[credentialRef] = credential;
  }
}
