import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';

void main() {
  group('live transfer harness safety', () {
    test('treats formatted EVM mainnet chain ids as known mainnets', () {
      expect(_isKnownEvmMainnet('1'), isTrue);
      expect(_isKnownEvmMainnet(' 1 '), isTrue);
      expect(_isKnownEvmMainnet('01'), isTrue);
      expect(_isKnownEvmMainnet('11155111'), isFalse);
      expect(_isKnownEvmMainnet('not-a-chain-id'), isFalse);
    });

    test('parses and validates Solana secret key byte lists', () {
      final bytes = List<int>.generate(64, (index) => index);

      expect(_parseSolanaSecretKey(jsonEncode(bytes)), bytes);
      expect(_parseSolanaSecretKey(bytes.join(',')), bytes);
      expect(
        () => _parseSolanaSecretKey(List<int>.filled(63, 1).join(',')),
        throwsFormatException,
      );
      expect(
        () => _parseSolanaSecretKey('${bytes.take(63).join(',')},256'),
        throwsFormatException,
      );
      expect(
        () => _parseSolanaSecretKey('{}'),
        throwsFormatException,
      );
    });

    test('skips ERC20 broadcast until token transfer config is provided', () {
      expect(
        _skipLiveErc20Transfer(),
        'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.',
      );
    });

    test('skips Bitcoin broadcast until transfer config is provided', () {
      expect(
        _skipLiveBitcoinTransfer(),
        'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.',
      );
    });

    test('treats configured Bitcoin mainnet endpoints as mainnet', () {
      expect(
        _isKnownBitcoinMainnet(
          network: 'mainnet',
          apiBaseUrl: 'https://blockstream.info/api',
        ),
        isTrue,
      );
      expect(
        _isKnownBitcoinMainnet(
          network: 'testnet',
          apiBaseUrl: 'https://blockstream.info/testnet/api',
        ),
        isFalse,
      );
    });
  });

  group('optional live transfer broadcast smoke', () {
    test(
      'broadcasts an EVM native transfer using configured testnet funds',
      () async {
        final chain = _liveEvmChain();
        final request = _evmTransferRequest(chain);
        final feeEstimate = await _estimateEvmFee(
          chain: chain,
          request: request,
        );

        final transactionHash =
            await const Web3EvmTransactionService().signAndBroadcast(
          EvmTransactionBroadcastInput(
            rpcUrl: _evmRpcUrl,
            chainId: int.parse(_evmChainId),
            privateKey: _evmPrivateKey,
            fromAddress: _evmFromAddress,
            transaction: request,
            feeEstimate: feeEstimate,
          ),
        );

        expect(transactionHash, startsWith('0x'));
        expect(transactionHash.length, greaterThan(10));
      },
      skip: _skipLiveEvmTransfer() ?? false,
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'broadcasts an EVM ERC20 transfer using configured testnet token funds',
      () async {
        final chain = _liveEvmChain();
        final request = _evmErc20TransferRequest(chain);
        final feeEstimate = await _estimateEvmFee(
          chain: chain,
          request: request,
        );

        final transactionHash =
            await const Web3EvmTransactionService().signAndBroadcast(
          EvmTransactionBroadcastInput(
            rpcUrl: _evmRpcUrl,
            chainId: int.parse(_evmChainId),
            privateKey: _evmPrivateKey,
            fromAddress: _evmFromAddress,
            transaction: request,
            feeEstimate: feeEstimate,
          ),
        );

        expect(transactionHash, startsWith('0x'));
        expect(transactionHash.length, greaterThan(10));
      },
      skip: _skipLiveErc20Transfer() ?? false,
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'broadcasts a Solana SOL transfer using configured testnet funds',
      () async {
        final request = _solanaTransferRequest();
        final feeEstimate =
            await const SdkSolanaFeeService().estimateSolTransferFee(
          rpcUrl: _solanaRpcUrl,
          fromAddress: _solanaFromAddress,
          toAddress: _solanaToAddress,
          lamports: BigInt.parse(_solanaAmountLamports),
        );

        final signature =
            await const SdkSolanaTransactionService().signAndBroadcast(
          SolanaTransactionBroadcastInput(
            rpcUrl: _solanaRpcUrl,
            privateKey: _parseSolanaSecretKey(_solanaPrivateKey),
            fromAddress: _solanaFromAddress,
            transaction: request,
            recentBlockhash: feeEstimate.recentBlockhash,
          ),
        );

        expect(signature, isNotEmpty);
      },
      skip: _skipLiveSolanaTransfer() ?? false,
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      'broadcasts a Bitcoin transfer using configured testnet funds',
      () async {
        final chain = _liveBitcoinChain();
        final request = _bitcoinTransferRequest(chain);
        final feeEstimate = await _estimateBitcoinFee(
          chain: chain,
          request: request,
        );

        final txid = await HttpBitcoinTransactionService().signAndBroadcast(
          BitcoinTransactionBroadcastInput(
            apiBaseUrl: _btcApiBaseUrl,
            privateKey: _btcPrivateKey,
            fromAddress: _btcFromAddress,
            transaction: request,
            feeEstimate: feeEstimate,
          ),
        );

        expect(txid, isNotEmpty);
      },
      skip: _skipLiveBitcoinTransfer() ?? false,
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}

const _liveTransferEnabled = bool.hasEnvironment('SAFE_WALLET_LIVE_TRANSFER')
    ? bool.fromEnvironment('SAFE_WALLET_LIVE_TRANSFER')
    : false;
const _allowMainnetTransfer =
    bool.hasEnvironment('SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET')
        ? bool.fromEnvironment('SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET')
        : false;

const _evmRpcUrl = String.fromEnvironment('SAFE_WALLET_LIVE_EVM_RPC_URL');
const _evmChainId = String.fromEnvironment('SAFE_WALLET_LIVE_EVM_CHAIN_ID');
const _evmSymbol =
    String.fromEnvironment('SAFE_WALLET_LIVE_EVM_SYMBOL', defaultValue: 'ETH');
const _evmPrivateKey =
    String.fromEnvironment('SAFE_WALLET_LIVE_EVM_PRIVATE_KEY');
const _evmFromAddress =
    String.fromEnvironment('SAFE_WALLET_LIVE_EVM_FROM_ADDRESS');
const _evmToAddress = String.fromEnvironment('SAFE_WALLET_LIVE_EVM_TO_ADDRESS');
const _evmAmountWei = String.fromEnvironment(
  'SAFE_WALLET_LIVE_EVM_AMOUNT_WEI',
  defaultValue: '1',
);
const _evmErc20ContractAddress = String.fromEnvironment(
  'SAFE_WALLET_LIVE_EVM_ERC20_CONTRACT_ADDRESS',
);
const _evmErc20Symbol = String.fromEnvironment(
  'SAFE_WALLET_LIVE_EVM_ERC20_SYMBOL',
  defaultValue: 'ERC20',
);
const _evmErc20Decimals = String.fromEnvironment(
  'SAFE_WALLET_LIVE_EVM_ERC20_DECIMALS',
  defaultValue: '18',
);
const _evmErc20AmountBaseUnits = String.fromEnvironment(
  'SAFE_WALLET_LIVE_EVM_ERC20_AMOUNT_BASE_UNITS',
  defaultValue: '1',
);

const _solanaRpcUrl = String.fromEnvironment('SAFE_WALLET_LIVE_SOLANA_RPC_URL');
const _solanaPrivateKey =
    String.fromEnvironment('SAFE_WALLET_LIVE_SOLANA_PRIVATE_KEY');
const _solanaFromAddress =
    String.fromEnvironment('SAFE_WALLET_LIVE_SOLANA_FROM_ADDRESS');
const _solanaToAddress =
    String.fromEnvironment('SAFE_WALLET_LIVE_SOLANA_TO_ADDRESS');
const _solanaAmountLamports = String.fromEnvironment(
  'SAFE_WALLET_LIVE_SOLANA_AMOUNT_LAMPORTS',
  defaultValue: '1',
);

const _btcApiBaseUrl =
    String.fromEnvironment('SAFE_WALLET_LIVE_BTC_API_BASE_URL');
const _btcNetwork = String.fromEnvironment(
  'SAFE_WALLET_LIVE_BTC_NETWORK',
  defaultValue: 'testnet',
);
const _btcPrivateKey =
    String.fromEnvironment('SAFE_WALLET_LIVE_BTC_PRIVATE_KEY');
const _btcFromAddress =
    String.fromEnvironment('SAFE_WALLET_LIVE_BTC_FROM_ADDRESS');
const _btcToAddress = String.fromEnvironment('SAFE_WALLET_LIVE_BTC_TO_ADDRESS');
const _btcAmountSatoshis = String.fromEnvironment(
  'SAFE_WALLET_LIVE_BTC_AMOUNT_SATOSHIS',
  defaultValue: '1',
);

String? _skipLiveEvmTransfer() {
  if (!_liveTransferEnabled) {
    return 'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.';
  }
  final missing = [
    if (_evmRpcUrl.isEmpty) 'SAFE_WALLET_LIVE_EVM_RPC_URL',
    if (_evmChainId.isEmpty) 'SAFE_WALLET_LIVE_EVM_CHAIN_ID',
    if (_evmPrivateKey.isEmpty) 'SAFE_WALLET_LIVE_EVM_PRIVATE_KEY',
    if (_evmFromAddress.isEmpty) 'SAFE_WALLET_LIVE_EVM_FROM_ADDRESS',
    if (_evmToAddress.isEmpty) 'SAFE_WALLET_LIVE_EVM_TO_ADDRESS',
  ];
  if (missing.isNotEmpty) {
    return 'Set ${missing.join(', ')} to run live EVM broadcast smoke.';
  }
  if (_isKnownEvmMainnet(_evmChainId) && !_allowMainnetTransfer) {
    return 'Refusing to broadcast on a known EVM mainnet without '
        'SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET=true.';
  }
  return null;
}

String? _skipLiveErc20Transfer() {
  if (!_liveTransferEnabled) {
    return 'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.';
  }
  final missing = [
    if (_evmRpcUrl.isEmpty) 'SAFE_WALLET_LIVE_EVM_RPC_URL',
    if (_evmChainId.isEmpty) 'SAFE_WALLET_LIVE_EVM_CHAIN_ID',
    if (_evmPrivateKey.isEmpty) 'SAFE_WALLET_LIVE_EVM_PRIVATE_KEY',
    if (_evmFromAddress.isEmpty) 'SAFE_WALLET_LIVE_EVM_FROM_ADDRESS',
    if (_evmToAddress.isEmpty) 'SAFE_WALLET_LIVE_EVM_TO_ADDRESS',
    if (_evmErc20ContractAddress.isEmpty)
      'SAFE_WALLET_LIVE_EVM_ERC20_CONTRACT_ADDRESS',
  ];
  if (missing.isNotEmpty) {
    return 'Set ${missing.join(', ')} to run live EVM ERC20 broadcast smoke.';
  }
  if (_isKnownEvmMainnet(_evmChainId) && !_allowMainnetTransfer) {
    return 'Refusing to broadcast on a known EVM mainnet without '
        'SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET=true.';
  }
  return null;
}

String? _skipLiveSolanaTransfer() {
  if (!_liveTransferEnabled) {
    return 'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.';
  }
  final missing = [
    if (_solanaRpcUrl.isEmpty) 'SAFE_WALLET_LIVE_SOLANA_RPC_URL',
    if (_solanaPrivateKey.isEmpty) 'SAFE_WALLET_LIVE_SOLANA_PRIVATE_KEY',
    if (_solanaFromAddress.isEmpty) 'SAFE_WALLET_LIVE_SOLANA_FROM_ADDRESS',
    if (_solanaToAddress.isEmpty) 'SAFE_WALLET_LIVE_SOLANA_TO_ADDRESS',
  ];
  if (missing.isNotEmpty) {
    return 'Set ${missing.join(', ')} to run live Solana broadcast smoke.';
  }
  if (_solanaRpcUrl.toLowerCase().contains('mainnet') &&
      !_allowMainnetTransfer) {
    return 'Refusing to broadcast on Solana mainnet without '
        'SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET=true.';
  }
  return null;
}

String? _skipLiveBitcoinTransfer() {
  if (!_liveTransferEnabled) {
    return 'Set SAFE_WALLET_LIVE_TRANSFER=true to run live broadcast smoke.';
  }
  final missing = [
    if (_btcApiBaseUrl.isEmpty) 'SAFE_WALLET_LIVE_BTC_API_BASE_URL',
    if (_btcPrivateKey.isEmpty) 'SAFE_WALLET_LIVE_BTC_PRIVATE_KEY',
    if (_btcFromAddress.isEmpty) 'SAFE_WALLET_LIVE_BTC_FROM_ADDRESS',
    if (_btcToAddress.isEmpty) 'SAFE_WALLET_LIVE_BTC_TO_ADDRESS',
  ];
  if (missing.isNotEmpty) {
    return 'Set ${missing.join(', ')} to run live Bitcoin broadcast smoke.';
  }
  if (_isKnownBitcoinMainnet(
        network: _btcNetwork,
        apiBaseUrl: _btcApiBaseUrl,
      ) &&
      !_allowMainnetTransfer) {
    return 'Refusing to broadcast on Bitcoin mainnet without '
        'SAFE_WALLET_LIVE_TRANSFER_ALLOW_MAINNET=true.';
  }
  return null;
}

bool _isKnownEvmMainnet(String chainId) {
  final normalizedChainId = int.tryParse(chainId.trim());
  return normalizedChainId != null &&
      const {1, 10, 56, 137, 42161, 8453}.contains(normalizedChainId);
}

bool _isKnownBitcoinMainnet({
  required String network,
  required String apiBaseUrl,
}) {
  final normalizedNetwork = network.trim().toLowerCase();
  if (normalizedNetwork == 'mainnet' ||
      normalizedNetwork == 'bitcoin-mainnet') {
    return true;
  }
  final normalizedUrl = apiBaseUrl.trim().toLowerCase();
  return normalizedUrl.contains('blockstream.info/api') &&
      !normalizedUrl.contains('testnet') &&
      !normalizedUrl.contains('signet');
}

ChainConfig _liveEvmChain() {
  return ChainConfig(
    id: 'live-evm-transfer',
    chainType: ChainType.evm,
    name: 'Configured EVM Testnet',
    chainId: _evmChainId,
    symbol: _evmSymbol,
    rpcUrls: const [_evmRpcUrl],
    blockExplorerUrl: null,
    isTestnet: true,
  );
}

ChainConfig _liveBitcoinChain() {
  final normalizedNetwork = _btcNetwork.trim().toLowerCase();
  return ChainConfig(
    id: 'live-bitcoin-transfer',
    chainType: ChainType.bitcoin,
    name:
        'Configured Bitcoin ${normalizedNetwork == 'mainnet' ? 'Mainnet' : 'Testnet'}',
    chainId: normalizedNetwork == 'mainnet'
        ? 'bitcoin-mainnet'
        : 'bitcoin-$normalizedNetwork',
    symbol: 'BTC',
    rpcUrls: const [_btcApiBaseUrl],
    blockExplorerUrl: null,
    isTestnet: normalizedNetwork != 'mainnet',
  );
}

TransactionRequest _evmTransferRequest(ChainConfig chain) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    toAddress: _evmToAddress,
    amount: _evmAmountWei,
    amountInBaseUnits: _evmAmountWei,
    tokenDecimals: 18,
    transactionType: TransactionType.nativeTransfer,
  );
}

TransactionRequest _evmErc20TransferRequest(ChainConfig chain) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: _evmErc20Symbol,
    toAddress: _evmToAddress,
    amount: _evmErc20AmountBaseUnits,
    amountInBaseUnits: _evmErc20AmountBaseUnits,
    tokenDecimals: int.parse(_evmErc20Decimals),
    tokenContractAddress: _evmErc20ContractAddress,
    transactionType: TransactionType.erc20Transfer,
  );
}

TransactionRequest _bitcoinTransferRequest(ChainConfig chain) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    toAddress: _btcToAddress,
    amount: _btcAmountSatoshis,
    amountInBaseUnits: _btcAmountSatoshis,
    tokenDecimals: 8,
    transactionType: TransactionType.bitcoinTransfer,
  );
}

Future<FeeEstimate> _estimateEvmFee({
  required ChainConfig chain,
  required TransactionRequest request,
}) async {
  final estimate = await const Web3EvmFeeService().estimateTransferFee(
    rpcUrl: _evmRpcUrl,
    fromAddress: _evmFromAddress,
    toAddress: _evmToAddress,
    transactionType: request.transactionType,
    amountInWei: BigInt.parse(request.amountInBaseUnits!),
    tokenContractAddress: request.tokenContractAddress,
  );
  return switch (estimate.model) {
    EvmFeeModel.eip1559 => FeeEstimate.eip1559(
        feeAssetSymbol: chain.symbol,
        gasLimit: estimate.gasLimit,
        maxFeePerGasWei: estimate.maxFeePerGasWei!,
        maxPriorityFeePerGasWei: estimate.maxPriorityFeePerGasWei!,
      ),
    EvmFeeModel.legacy => FeeEstimate.legacy(
        feeAssetSymbol: chain.symbol,
        gasLimit: estimate.gasLimit,
        gasPriceWei: estimate.gasPriceWei!,
      ),
  };
}

Future<FeeEstimate> _estimateBitcoinFee({
  required ChainConfig chain,
  required TransactionRequest request,
}) async {
  final estimate = await HttpBitcoinFeeService().estimateTransferFee(
    apiBaseUrl: _btcApiBaseUrl,
    fromAddress: _btcFromAddress,
    toAddress: _btcToAddress,
    satoshis: BigInt.parse(request.amountInBaseUnits!),
  );
  return FeeEstimate.bitcoin(
    feeAssetSymbol: chain.symbol,
    satoshis: estimate.satoshis,
  );
}

TransactionRequest _solanaTransferRequest() {
  return TransactionRequest(
    chainId: 'devnet',
    chainType: ChainType.solana,
    assetSymbol: 'SOL',
    toAddress: _solanaToAddress,
    amount: _solanaAmountLamports,
    amountInBaseUnits: _solanaAmountLamports,
    tokenDecimals: 9,
    transactionType: TransactionType.solTransfer,
  );
}

List<int> _parseSolanaSecretKey(String value) {
  final trimmed = value.trim();
  final parts = trimmed.startsWith('[')
      ? (jsonDecode(trimmed) as List<dynamic>)
      : trimmed.split(',');
  final bytes = parts.map((part) {
    final parsed = int.parse(part.toString().trim());
    if (parsed < 0 || parsed > 255) {
      throw FormatException('Solana secret key byte out of range: $parsed');
    }
    return parsed;
  }).toList(growable: false);
  if (bytes.length != 64) {
    throw FormatException(
      'Solana secret key must contain 64 bytes, got ${bytes.length}',
    );
  }
  return bytes;
}
