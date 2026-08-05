import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/data/token_universe_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsonTokenUniverseRepository', () {
    test('loads top tokens from chain json with limit applied', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final requestedPaths = <String>[];
      final repository = JsonTokenUniverseRepository(
        loadString: (path) async {
          requestedPaths.add(path);
          return '''
{
  "chainId": "1",
  "tokens": [
    {
      "chainId": "1",
      "contractAddress": "0x0000000000000000000000000000000000000001",
      "symbol": "ONE",
      "name": "One",
      "decimals": 18,
      "logoUri": "https://example.com/one.png"
    },
    {
      "chainId": "1",
      "contractAddress": "0x0000000000000000000000000000000000000002",
      "symbol": "TWO",
      "name": "Two",
      "decimals": 6,
      "logoUri": "asset:assets/token_logos/usdc.svg"
    }
  ]
}
''';
        },
      );

      final ethereumTokens = await repository.getTopTokens(
        chain: ethereum,
        limit: 1,
      );

      expect(ethereumTokens.map((token) => token.symbol), ['ONE']);
      expect(ethereumTokens.single.logoUri, 'https://example.com/one.png');
      expect(requestedPaths, ['assets/token_universe/1.json']);
    });

    test('ignores malformed native and wrong-chain entries', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = JsonTokenUniverseRepository(
        loadString: (_) async => '''
{
  "tokens": [
    {
      "chainId": "1",
      "contractAddress": null,
      "symbol": "ETH",
      "name": "Ethereum",
      "decimals": 18
    },
    {
      "chainId": "56",
      "contractAddress": "0x0000000000000000000000000000000000000001",
      "symbol": "BSC",
      "name": "BSC Token",
      "decimals": 18
    },
    {
      "chainId": "1",
      "contractAddress": "0x0000000000000000000000000000000000000002",
      "symbol": "USDC",
      "name": "USD Coin",
      "decimals": 6
    }
  ]
}
''',
      );

      final tokens = await repository.getTopTokens(chain: ethereum);

      expect(tokens.map((token) => token.symbol), ['USDC']);
    });

    test('loads memo requirement metadata from chain json', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = JsonTokenUniverseRepository(
        loadString: (_) async => '''
{
  "tokens": [
    {
      "chainId": "1",
      "contractAddress": "0x0000000000000000000000000000000000000001",
      "symbol": "TAG",
      "name": "Tagged Token",
      "decimals": 18,
      "requiresMemo": true,
      "memoLabel": "Destination Tag"
    }
  ]
}
''',
      );

      final tokens = await repository.getTopTokens(chain: ethereum);

      expect(tokens.single.requiresMemo, isTrue);
      expect(tokens.single.memoLabel, 'Destination Tag');
    });

    test('loads Solana universe from solana json alias', () async {
      final solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      final requestedPaths = <String>[];
      final repository = JsonTokenUniverseRepository(
        loadString: (path) async {
          requestedPaths.add(path);
          return '''
{
  "chainId": "solana",
  "tokens": [
    {
      "chainId": "solana",
      "contractAddress": "So11111111111111111111111111111111111111112",
      "symbol": "WSOL",
      "name": "Wrapped SOL",
      "decimals": 9
    }
  ]
}
''';
        },
      );

      final tokens = await repository.getTopTokens(chain: solana);

      expect(requestedPaths, ['assets/token_universe/solana.json']);
      expect(tokens.single.symbol, 'WSOL');
      expect(tokens.single.chainId, solana.chainId);
    });

    test('maps Sui token universe aliases and preserves Move Coin types',
        () async {
      final sui =
          defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
      final requestedPaths = <String>[];
      final repository = JsonTokenUniverseRepository(
        loadString: (path) async {
          requestedPaths.add(path);
          return '''
{
  "chainId": "sui",
  "tokens": [
    {
      "chainId": "sui",
      "contractAddress": "0xabc::coin::USDC",
      "symbol": "USDC",
      "name": "USD Coin",
      "decimals": 6
    }
  ]
}
''';
        },
      );

      final tokens = await repository.getTopTokens(chain: sui);

      expect(requestedPaths, ['assets/token_universe/sui.json']);
      expect(tokens.single.chainId, 'sui:mainnet');
      expect(tokens.single.contractAddress, '0xabc::coin::USDC');
    });

    test('falls back to built-in tokens when the json asset is unavailable',
        () async {
      final bnb = defaultChains.firstWhere(
        (chain) => chain.id == 'bnb-smart-chain',
      );
      final repository = JsonTokenUniverseRepository(
        loadString: (_) => throw Exception('missing asset'),
      );

      final tokens = await repository.getTopTokens(chain: bnb, limit: 2);

      expect(tokens, hasLength(2));
      expect(tokens.every((token) => token.chainId == bnb.chainId), isTrue);
    });

    test('loads bundled top 100 token json for default chains', () async {
      const repository = JsonTokenUniverseRepository();
      const expectedChainIds = {
        '1',
        '56',
        '137',
        '42161',
        '10',
        '8453',
        '999',
        'mainnet-beta',
      };
      final chains = defaultChains.where(
        (chain) => expectedChainIds.contains(chain.chainId),
      );

      for (final chain in chains) {
        final tokens = await repository.getTopTokens(chain: chain);

        expect(tokens, hasLength(100), reason: chain.chainId);
        expect(
          tokens.every(
            (token) =>
                token.chainId == chain.chainId &&
                token.contractAddress != null &&
                token.symbol.isNotEmpty &&
                token.name.isNotEmpty,
          ),
          isTrue,
          reason: chain.chainId,
        );
      }
    });

    test('bundled token logos do not use CoinGecko thumb images', () async {
      const repository = JsonTokenUniverseRepository();
      const expectedChainIds = {
        '1',
        '56',
        '137',
        '42161',
        '10',
        '8453',
        '999',
        'mainnet-beta',
      };
      final chains = defaultChains.where(
        (chain) => expectedChainIds.contains(chain.chainId),
      );

      for (final chain in chains) {
        final tokens = await repository.getTopTokens(chain: chain);

        expect(
          tokens
              .map((token) => token.logoUri ?? '')
              .where((logoUri) => logoUri.contains('/thumb/')),
          isEmpty,
          reason: chain.chainId,
        );
      }
    });
  });
}
