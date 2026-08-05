import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/manual_token_add_controller.dart';
import 'package:safe_wallet/features/assets/application/token_discovery_controller.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/evm_token_discovery_service.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/data/tron_asset_service.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';

void main() {
  group('ManualTokenAddController', () {
    test('EVM add reads metadata and balance before saving token', () async {
      final repository = _RecordingTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient(
        metadata: const EvmTokenMetadata(
          name: 'USD Coin',
          symbol: 'USDC',
          decimals: 6,
        ),
        balance: BigInt.from(123),
      );
      final container = _container(repository: repository, client: client);
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );

      final token = await container
          .read(manualTokenAddControllerProvider.notifier)
          .addToken(
            chain: ethereum,
            rpcUrl: 'https://rpc.example.com',
            walletAddress: '0x1111111111111111111111111111111111111111',
            contractAddress: '0xA0B86991C6218B36C1D19D4A2E9EB0CE3606EB48',
          );

      expect(client.balanceCalls, hasLength(1));
      expect(client.metadataCalls, hasLength(1));
      expect(
        token.contractAddress,
        '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
      );
      expect(token.name, 'USD Coin');
      expect(token.symbol, 'USDC');
      expect(token.decimals, 6);
      expect(token.source, TokenSource.userAdded);
      expect(repository.savedTokens, [token]);
    });

    test('metadata failure uses manually supplied metadata', () async {
      final repository = _RecordingTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient(
        metadataError: StateError('metadata failed'),
        balance: BigInt.zero,
      );
      final container = _container(repository: repository, client: client);
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );

      final token = await container
          .read(manualTokenAddControllerProvider.notifier)
          .addToken(
            chain: ethereum,
            rpcUrl: 'https://rpc.example.com',
            walletAddress: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x2222222222222222222222222222222222222222',
            symbol: 'SAFE',
            name: 'Safe Token',
            decimals: 18,
          );

      expect(client.balanceCalls, hasLength(1));
      expect(client.metadataCalls, hasLength(1));
      expect(token.name, 'Safe Token');
      expect(token.symbol, 'SAFE');
      expect(token.decimals, 18);
      expect(repository.savedTokens, [token]);
    });

    test('metadata failure without manual metadata blocks saving', () async {
      final repository = _RecordingTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient(
        metadataError: StateError('metadata failed'),
        balance: BigInt.zero,
      );
      final container = _container(repository: repository, client: client);
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );

      await expectLater(
        container
            .read(manualTokenAddControllerProvider.notifier)
            .addToken(
              chain: ethereum,
              rpcUrl: 'https://rpc.example.com',
              walletAddress: '0x1111111111111111111111111111111111111111',
              contractAddress: '0x2222222222222222222222222222222222222222',
            ),
        throwsA(isA<ManualTokenMetadataRequired>()),
      );

      expect(repository.savedTokens, isEmpty);
    });

    test('Bitcoin does not support manually added contract tokens', () async {
      final repository = _RecordingTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient(balance: BigInt.zero);
      final container = _container(repository: repository, client: client);
      final bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );

      await expectLater(
        container
            .read(manualTokenAddControllerProvider.notifier)
            .addToken(
              chain: bitcoin,
              rpcUrl: 'https://blockstream.info/api',
              walletAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
              contractAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
              symbol: 'ORD',
              name: 'Ordinal Token',
              decimals: 0,
            ),
        throwsA(isA<UnsupportedError>()),
      );

      expect(client.balanceCalls, isEmpty);
      expect(client.metadataCalls, isEmpty);
      expect(repository.savedTokens, isEmpty);
    });

    test(
      'Tron add validates balance and uses manually supplied metadata',
      () async {
        final repository = _RecordingTokenRepository();
        final client = _FakeEvmTokenDiscoveryClient(balance: BigInt.zero);
        final tronService = _FakeTronAssetService(balance: BigInt.from(123));
        final container = _container(
          repository: repository,
          client: client,
          tronService: tronService,
        );
        final tron = defaultChains.firstWhere(
          (chain) => chain.id == 'tron-mainnet',
        );

        final token = await container
            .read(manualTokenAddControllerProvider.notifier)
            .addToken(
              chain: tron,
              rpcUrl: 'https://api.trongrid.io',
              walletAddress: _tronWalletAddress,
              contractAddress: _trc20ContractAddress,
              symbol: 'usdt',
              name: 'Tether USD',
              decimals: 6,
            );

        expect(tronService.trc20BalanceCalls, [
          (
            apiBaseUrl: 'https://api.trongrid.io',
            walletAddress: _tronWalletAddress,
            contractAddress: _trc20ContractAddress,
          ),
        ]);
        expect(client.balanceCalls, isEmpty);
        expect(client.metadataCalls, isEmpty);
        expect(token.contractAddress, _trc20ContractAddress);
        expect(token.name, 'Tether USD');
        expect(token.symbol, 'USDT');
        expect(token.decimals, 6);
        expect(token.source, TokenSource.userAdded);
        expect(repository.savedTokens, [token]);
      },
    );

    test('Tron add requires manually supplied metadata', () async {
      final repository = _RecordingTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient(balance: BigInt.zero);
      final tronService = _FakeTronAssetService(balance: BigInt.from(123));
      final container = _container(
        repository: repository,
        client: client,
        tronService: tronService,
      );
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );

      await expectLater(
        container
            .read(manualTokenAddControllerProvider.notifier)
            .addToken(
              chain: tron,
              rpcUrl: 'https://api.trongrid.io',
              walletAddress: _tronWalletAddress,
              contractAddress: _trc20ContractAddress,
            ),
        throwsA(isA<ManualTokenMetadataRequired>()),
      );

      expect(tronService.trc20BalanceCalls, [
        (
          apiBaseUrl: 'https://api.trongrid.io',
          walletAddress: _tronWalletAddress,
          contractAddress: _trc20ContractAddress,
        ),
      ]);
      expect(repository.savedTokens, isEmpty);
    });
  });
}

ProviderContainer _container({
  required TokenRepository repository,
  required EvmTokenDiscoveryClient client,
  TronAssetService? tronService,
}) {
  final container = ProviderContainer(
    overrides: [
      tokenRepositoryProvider.overrideWithValue(repository),
      evmTokenDiscoveryClientProvider.overrideWithValue(client),
      if (tronService != null)
        tronAssetServiceProvider.overrideWithValue(tronService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final class _RecordingTokenRepository implements TokenRepository {
  final savedTokens = <TokenInfo>[];

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return List.unmodifiable(
      savedTokens.where((token) => token.chainId == chainId),
    );
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) async {
    savedTokens.add(token);
    return token;
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeTronAssetService implements TronAssetService {
  _FakeTronAssetService({required this.balance});

  final BigInt balance;
  final trc20BalanceCalls =
      <({String apiBaseUrl, String walletAddress, String contractAddress})>[];

  @override
  Future<BigInt> getTrxBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, BigInt>> getTrc20Balances({
    required String apiBaseUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    for (final contractAddress in contractAddresses) {
      trc20BalanceCalls.add((
        apiBaseUrl: apiBaseUrl,
        walletAddress: walletAddress,
        contractAddress: contractAddress,
      ));
    }
    return {
      for (final contractAddress in contractAddresses) contractAddress: balance,
    };
  }
}

final class _FakeEvmTokenDiscoveryClient implements EvmTokenDiscoveryClient {
  _FakeEvmTokenDiscoveryClient({
    this.metadata,
    this.metadataError,
    required this.balance,
  });

  final EvmTokenMetadata? metadata;
  final Object? metadataError;
  final BigInt balance;
  final balanceCalls = <String>[];
  final metadataCalls = <String>[];

  @override
  Future<int> latestBlockNumber({
    required String rpcUrl,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BigInt> readBalance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    balanceCalls.add(contractAddress);
    return balance;
  }

  @override
  Future<EvmTokenMetadata> readMetadata({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    metadataCalls.add(contractAddress);
    final error = metadataError;
    if (error != null) {
      throw error;
    }
    return metadata!;
  }

  @override
  Future<List<String>> scanTransferContracts({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}

const _tronWalletAddress = 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
