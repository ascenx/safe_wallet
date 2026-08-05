import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/data/hive_chain_repository.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/storage_keys.dart';

void main() {
  group('HiveChainRepository', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_chains_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
        'seeds the required default EVM, Bitcoin, Tron, Solana, and Sui chains',
        () async {
      final repository = await _createRepository(tempDirectory);

      final chains = await repository.getChains();

      expect(chains, hasLength(14));
      expect(chains.map((chain) => chain.id), [
        'ethereum',
        'bnb-smart-chain',
        'polygon',
        'arbitrum',
        'optimism',
        'base',
        'hyperevm',
        'bitcoin-mainnet',
        'tron-mainnet',
        'solana-mainnet',
        'solana-devnet',
        'sui-mainnet',
        'sui-testnet',
        'sui-devnet',
      ]);
      expect(chains.where((chain) => chain.chainType == ChainType.evm),
          hasLength(7));
      expect(
        chains.where((chain) => chain.chainType == ChainType.bitcoin),
        hasLength(1),
      );
      expect(
        chains.where((chain) => chain.id == 'tron-mainnet'),
        hasLength(1),
      );
      expect(
        chains.where((chain) => chain.chainType == ChainType.solana),
        hasLength(2),
      );
      expect(
        chains.where((chain) => chain.chainType == ChainType.sui),
        hasLength(3),
      );
      final bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      expect(bitcoin.chainId, 'bitcoin-mainnet');
      expect(bitcoin.symbol, 'BTC');
      expect(bitcoin.rpcUrls, ['https://blockstream.info/api']);
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );
      expect(tron.chainId, 'tron-mainnet');
      expect(tron.symbol, 'TRX');
      expect(tron.rpcUrls, ['https://api.trongrid.io']);
      expect(tron.blockExplorerUrl, 'https://tronscan.org');
      expect(
        defaultChains
            .firstWhere((chain) => chain.id == 'solana-mainnet')
            .chainId,
        'mainnet-beta',
      );
      final hyperevm = defaultChains.firstWhere(
        (chain) => chain.id == 'hyperevm',
      );
      expect(hyperevm.chainId, '999');
      expect(hyperevm.symbol, 'HYPE');
      final suiMainnet = defaultChains.firstWhere(
        (chain) => chain.id == 'sui-mainnet',
      );
      expect(suiMainnet.chainId, 'sui:mainnet');
      expect(suiMainnet.symbol, 'SUI');
      expect(suiMainnet.rpcUrls, ['https://fullnode.mainnet.sui.io:443']);
      expect(suiMainnet.blockExplorerUrl, 'https://suiscan.xyz/mainnet');
      expect(suiMainnet.isTestnet, isFalse);
    });

    test('defaults to Ethereum and persists selected chain changes', () async {
      final initializer = StorageInitializer(path: tempDirectory.path);
      final registry = await initializer.initialize();
      final repository = HiveChainRepository(registry: registry);

      final initial = await repository.getSelectedChain();

      expect(initial.id, 'ethereum');

      final selected = await repository.selectChain('solana-mainnet');

      expect(selected.id, 'solana-mainnet');
      expect(
        registry.settingsBox.get(StorageKeys.selectedChainId),
        'solana-mainnet',
      );

      final secondRepository = HiveChainRepository(registry: registry);
      final restored = await secondRepository.getSelectedChain();

      expect(restored.id, 'solana-mainnet');
    });

    test('adds custom EVM chain and persists it', () async {
      final repository = await _createRepository(tempDirectory);

      final custom = await repository.addCustomEvmChain(
        name: 'Local Testnet',
        chainId: '31337',
        rpcUrl: 'http://127.0.0.1:8545',
        symbol: 'ETH',
        blockExplorerUrl: 'http://127.0.0.1:4000',
        isTestnet: true,
      );

      final restoredRepository = await _reopenRepository(tempDirectory);
      final chains = await restoredRepository.getChains();
      final restored = chains.firstWhere((chain) => chain.id == custom.id);

      expect(custom.id, 'custom-evm-31337');
      expect(restored.chainType, ChainType.evm);
      expect(restored.name, 'Local Testnet');
      expect(restored.chainId, '31337');
      expect(restored.rpcUrls, isEmpty);
      expect(restored.blockExplorerUrl, 'http://127.0.0.1:4000');
      expect(restored.isTestnet, isTrue);
    });

    test('deletes custom chains but keeps default chains', () async {
      final repository = await _createRepository(tempDirectory);
      final custom = await repository.addCustomEvmChain(
        name: 'Local Testnet',
        chainId: '31337',
        rpcUrl: 'http://127.0.0.1:8545',
        symbol: 'ETH',
      );

      await (repository as RemovableChainRepository).deleteChain(custom.id);

      final chainsAfterDelete = await repository.getChains();
      expect(chainsAfterDelete.any((chain) => chain.id == custom.id), isFalse);
      await expectLater(
        (repository as RemovableChainRepository).deleteChain('hyperevm'),
        throwsStateError,
      );
    });
  });
}

Future<ChainRepository> _createRepository(Directory directory) async {
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveChainRepository(registry: registry);
}

Future<ChainRepository> _reopenRepository(Directory directory) async {
  await Hive.close();
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveChainRepository(registry: registry);
}
