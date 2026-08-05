import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/assets/data/hive_token_repository.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('HiveTokenRepository', () {
    late Directory tempDirectory;
    late String ethereumChainId;
    late String bnbChainId;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_tokens_test_',
      );
      ethereumChainId =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum').chainId;
      bnbChainId = defaultChains
          .firstWhere((chain) => chain.id == 'bnb-smart-chain')
          .chainId;
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('seeds built-in Ethereum mainnet tokens', () async {
      final repository = await _createRepository(tempDirectory);

      final tokens = await repository.getTokens(chainId: ethereumChainId);

      expect(tokens.map((token) => token.symbol),
          containsAll(['USDT', 'USDC', 'DAI', 'WETH']));
      expect(
          tokens.every((token) => token.source == TokenSource.builtIn), isTrue);
    });

    test('seeds built-in BNB Smart Chain stable tokens', () async {
      final repository = await _createRepository(tempDirectory);

      final tokens = await repository.getTokens(chainId: bnbChainId);

      expect(
          tokens.map((token) => token.symbol), containsAll(['USDT', 'USDC']));
      expect(
          tokens.every((token) => token.source == TokenSource.builtIn), isTrue);
    });

    test('seeds popular built-in tokens with logos for default mainnet chains',
        () async {
      final repository = await _createRepository(tempDirectory);
      final expectedSymbolsByChain = <String, List<String>>{
        '1': ['USDT', 'USDC', 'DAI', 'WETH', 'WBTC', 'LINK', 'UNI'],
        '56': ['USDT', 'USDC', 'DAI', 'FDUSD', 'WBNB', 'BTCB', 'ETH', 'CAKE'],
        '137': [
          'USDT',
          'USDC',
          'USDC.e',
          'DAI',
          'WPOL',
          'WETH',
          'WBTC',
          'LINK',
        ],
        '42161': [
          'USDT',
          'USDC',
          'USDC.e',
          'DAI',
          'WETH',
          'WBTC',
          'ARB',
        ],
        '10': ['USDT', 'USDC', 'USDC.e', 'DAI', 'WETH', 'WBTC', 'OP'],
        '8453': ['USDC', 'USDbC', 'DAI', 'WETH', 'cbBTC', 'EURC', 'AERO'],
        '999': ['WHYPE'],
        'mainnet-beta': [
          'WSOL',
          'USDC',
          'USDT',
          'PYUSD',
          'JUP',
          'BONK',
          'WIF',
          'RAY',
        ],
        'devnet': ['WSOL'],
      };

      for (final entry in expectedSymbolsByChain.entries) {
        final tokens = await repository.getTokens(chainId: entry.key);
        final symbols = tokens.map((token) => token.symbol).toList();
        expect(symbols, containsAll(entry.value), reason: entry.key);
        final expectedTokens =
            tokens.where((token) => entry.value.contains(token.symbol));
        expect(
          expectedTokens.every(
            (token) => token.logoUri != null && token.logoUri!.isNotEmpty,
          ),
          isTrue,
          reason: entry.key,
        );
        for (final token in expectedTokens) {
          expect(token.logoUri, startsWith('asset:'), reason: token.symbol);
          expect(token.logoUri, endsWith('.svg'), reason: token.symbol);
          expect(
            File(token.logoUri!.replaceFirst('asset:', '')).existsSync(),
            isTrue,
            reason: token.logoUri,
          );
        }
      }
    });

    test('refreshes stored built-in token logos to bundled svg assets',
        () async {
      final repository = await _createRepository(tempDirectory);
      final builtInUsdt = builtInTokens.firstWhere(
        (token) => token.chainId == bnbChainId && token.symbol == 'USDT',
      );
      final oldStoredUsdt = TokenInfo(
        chainId: builtInUsdt.chainId,
        contractAddress: builtInUsdt.contractAddress,
        symbol: builtInUsdt.symbol,
        name: builtInUsdt.name,
        decimals: builtInUsdt.decimals,
        source: TokenSource.builtIn,
        isHidden: true,
        logoUri: 'asset:assets/token_logos/usdt.png',
      );

      await repository.saveToken(oldStoredUsdt);

      final tokens = await repository.getTokens(
        chainId: bnbChainId,
        includeHidden: true,
      );
      final usdt = tokens.firstWhere(
        (token) => token.contractAddress == builtInUsdt.contractAddress,
      );

      expect(usdt.isHidden, isTrue);
      expect(usdt.logoUri, builtInUsdt.logoUri);
      expect(usdt.logoUri, endsWith('.svg'));
    });

    test('refreshes discovered known tokens to built-in svg logo metadata',
        () async {
      final repository = await _createRepository(tempDirectory);
      final builtInUsdc = builtInTokens.firstWhere(
        (token) => token.chainId == bnbChainId && token.symbol == 'USDC',
      );
      final discoveredUsdc = TokenInfo(
        chainId: builtInUsdc.chainId,
        contractAddress: builtInUsdc.contractAddress,
        symbol: builtInUsdc.symbol,
        name: builtInUsdc.name,
        decimals: builtInUsdc.decimals,
        source: TokenSource.discovered,
        isHidden: true,
      );

      await repository.saveToken(discoveredUsdc);

      final tokens = await repository.getTokens(
        chainId: bnbChainId,
        includeHidden: true,
      );
      final usdc = tokens.firstWhere(
        (token) => token.contractAddress == builtInUsdc.contractAddress,
      );

      expect(usdc.source, TokenSource.builtIn);
      expect(usdc.isHidden, isTrue);
      expect(usdc.logoUri, builtInUsdc.logoUri);
      expect(usdc.logoUri, endsWith('.svg'));
    });

    test('adds manual token and persists it', () async {
      final repository = await _createRepository(tempDirectory);
      const token = TokenInfo(
        chainId: '1',
        contractAddress: '0x1111111111111111111111111111111111111111',
        symbol: 'SAFE',
        name: 'Safe Token',
        decimals: 18,
        source: TokenSource.userAdded,
        isHidden: false,
      );

      await repository.saveToken(token);

      final restored = await _reopenRepository(tempDirectory);
      final tokens = await restored.getTokens(chainId: ethereumChainId);

      expect(tokens, contains(token));
    });

    test('hidden token stays hidden after discovery saves it again', () async {
      final repository = await _createRepository(tempDirectory);
      const hidden = TokenInfo(
        chainId: '1',
        contractAddress: '0x2222222222222222222222222222222222222222',
        symbol: 'HIDE',
        name: 'Hidden Token',
        decimals: 18,
        source: TokenSource.discovered,
        isHidden: false,
      );

      await repository.saveToken(hidden);
      await repository.hideToken(
        chainId: hidden.chainId,
        contractAddress: hidden.contractAddress!,
      );
      await repository.saveToken(hidden);

      final visibleTokens =
          await repository.getTokens(chainId: ethereumChainId);
      final allTokens = await repository.getTokens(
        chainId: ethereumChainId,
        includeHidden: true,
      );

      expect(visibleTokens.any((token) => token.symbol == 'HIDE'), isFalse);
      expect(
        allTokens.firstWhere((token) => token.symbol == 'HIDE').isHidden,
        isTrue,
      );
    });

    test('last scanned block is stored per wallet and chain', () async {
      final repository = await _createRepository(tempDirectory);

      await repository.setLastScannedBlock(
        chainId: ethereumChainId,
        walletAddress: '0xabc',
        blockNumber: 123,
      );

      expect(
        await repository.getLastScannedBlock(
          chainId: ethereumChainId,
          walletAddress: '0xabc',
        ),
        123,
      );
      expect(
        await repository.getLastScannedBlock(
          chainId: ethereumChainId,
          walletAddress: '0xdef',
        ),
        isNull,
      );
    });
  });
}

Future<TokenRepository> _createRepository(Directory directory) async {
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveTokenRepository(registry: registry);
}

Future<TokenRepository> _reopenRepository(Directory directory) async {
  await Hive.close();
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveTokenRepository(registry: registry);
}
