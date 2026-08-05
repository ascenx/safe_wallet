import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/data/evm_token_discovery_service.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';

void main() {
  test(
    'discovers token universe balances without scanning transfer history',
    () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      const usdc = TokenInfo(
        chainId: '1',
        contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: 'assets/tokens/usdc.svg',
      );
      const link = TokenInfo(
        chainId: '1',
        contractAddress: '0x514910771af9ca656af840dff83e8264ecf986ca',
        symbol: 'LINK',
        name: 'Chainlink',
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
      );
      final client = _FakeEvmTokenDiscoveryClient(
        balancesByAddress: {
          usdc.contractAddress!: BigInt.from(1000000),
          link.contractAddress!: BigInt.zero,
        },
      );
      final service = EvmTokenDiscoveryService(client: client);

      final result = await service.discover(
        chain: ethereum,
        rpcUrl: 'https://rpc.example.com',
        walletAddress: '0x1111111111111111111111111111111111111111',
        fromBlock: 0,
        candidateTokens: const [usdc, link],
        rpcHeaders: const {'x-api-key': 'secret'},
      );

      expect(client.scanCalls, isEmpty);
      expect(client.balanceCalls, [usdc.contractAddress, link.contractAddress]);
      expect(client.balanceHeaders, const {'x-api-key': 'secret'});
      expect(result.lastScannedBlock, isNull);
      expect(result.tokens, const [
        TokenInfo(
          chainId: '1',
          contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          symbol: 'USDC',
          name: 'USD Coin',
          decimals: 6,
          source: TokenSource.discovered,
          isHidden: false,
          logoUri: 'assets/tokens/usdc.svg',
        ),
      ]);
    },
  );

  test(
    'discovers Transfer contracts only when balanceOf confirms balance',
    () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final client = _FakeEvmTokenDiscoveryClient(
        latestBlock: 150,
        transferContracts: const [
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          '0x0000000000000000000000000000000000000000',
        ],
        metadataByAddress: const {
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': EvmTokenMetadata(
            name: 'USD Coin',
            symbol: 'USDC',
            decimals: 6,
          ),
          '0x0000000000000000000000000000000000000000': EvmTokenMetadata(
            name: 'Zero Token',
            symbol: 'ZERO',
            decimals: 18,
          ),
        },
        balancesByAddress: {
          '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': BigInt.from(1000000),
          '0x0000000000000000000000000000000000000000': BigInt.zero,
        },
      );
      final service = EvmTokenDiscoveryService(client: client);

      final result = await service.discover(
        chain: ethereum,
        rpcUrl: 'https://rpc.example.com',
        walletAddress: '0x1111111111111111111111111111111111111111',
        fromBlock: 100,
      );

      expect(
        client.scannedWalletAddress,
        '0x1111111111111111111111111111111111111111',
      );
      expect(client.scanCalls.single.fromBlock, 100);
      expect(client.scanCalls.single.toBlock, 150);
      expect(result.lastScannedBlock, 150);
      expect(result.tokens, hasLength(1));
      expect(
        result.tokens.single,
        const TokenInfo(
          chainId: '1',
          contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          symbol: 'USDC',
          name: 'USD Coin',
          decimals: 6,
          source: TokenSource.discovered,
          isHidden: false,
        ),
      );
    },
  );

  test('splits large Transfer log scans into bounded block ranges', () async {
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    final client = _FakeEvmTokenDiscoveryClient(
      latestBlock: 150,
      transferContracts: const ['0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'],
      metadataByAddress: const {
        '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': EvmTokenMetadata(
          name: 'USD Coin',
          symbol: 'USDC',
          decimals: 6,
        ),
      },
      balancesByAddress: {
        '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': BigInt.one,
      },
    );
    final service = EvmTokenDiscoveryService(
      client: client,
      maxScanBlockRange: 25,
    );

    final result = await service.discover(
      chain: ethereum,
      rpcUrl: 'https://rpc.example.com',
      walletAddress: '0x1111111111111111111111111111111111111111',
      fromBlock: 100,
    );

    expect(client.scanCalls, const [
      _ScanCall(fromBlock: 100, toBlock: 124),
      _ScanCall(fromBlock: 125, toBlock: 149),
      _ScanCall(fromBlock: 150, toBlock: 150),
    ]);
    expect(result.lastScannedBlock, 150);
    expect(result.tokens, hasLength(1));
  });

  test(
    'discovery failure reports error without producing candidates',
    () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final service = EvmTokenDiscoveryService(
        client: _FakeEvmTokenDiscoveryClient(shouldFail: true),
      );

      final result = await service.discover(
        chain: ethereum,
        rpcUrl: 'https://rpc.example.com',
        walletAddress: '0x1111111111111111111111111111111111111111',
        fromBlock: 100,
      );

      expect(result.tokens, isEmpty);
      expect(result.errorMessage, isNotNull);
    },
  );
}

final class _FakeEvmTokenDiscoveryClient implements EvmTokenDiscoveryClient {
  _FakeEvmTokenDiscoveryClient({
    this.latestBlock = 120,
    this.transferContracts = const [],
    this.metadataByAddress = const {},
    this.balancesByAddress = const {},
    this.shouldFail = false,
  });

  final int latestBlock;
  final List<String> transferContracts;
  final Map<String, EvmTokenMetadata> metadataByAddress;
  final Map<String, BigInt> balancesByAddress;
  final bool shouldFail;
  String? scannedWalletAddress;
  final scanCalls = <_ScanCall>[];
  final balanceCalls = <String>[];
  Map<String, String>? balanceHeaders;

  @override
  Future<int> latestBlockNumber({
    required String rpcUrl,
    Map<String, String> headers = const {},
  }) async {
    if (shouldFail) {
      throw StateError('rpc failed');
    }
    return latestBlock;
  }

  @override
  Future<BigInt> readBalance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    balanceCalls.add(contractAddress);
    balanceHeaders = headers;
    return balancesByAddress[contractAddress.toLowerCase()] ?? BigInt.zero;
  }

  @override
  Future<EvmTokenMetadata> readMetadata({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    return metadataByAddress[contractAddress.toLowerCase()]!;
  }

  @override
  Future<List<String>> scanTransferContracts({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    Map<String, String> headers = const {},
  }) async {
    scannedWalletAddress = walletAddress;
    scanCalls.add(_ScanCall(fromBlock: fromBlock, toBlock: toBlock));
    return transferContracts;
  }
}

final class _ScanCall {
  const _ScanCall({required this.fromBlock, required this.toBlock});

  final int fromBlock;
  final int toBlock;

  @override
  bool operator ==(Object other) {
    return other is _ScanCall &&
        other.fromBlock == fromBlock &&
        other.toBlock == toBlock;
  }

  @override
  int get hashCode => Object.hash(fromBlock, toBlock);
}
