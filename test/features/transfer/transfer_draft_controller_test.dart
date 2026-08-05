import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/application/transfer_draft_controller.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';

void main() {
  group('TransferDraftController', () {
    late ChainConfig ethereum;
    late ProviderContainer container;

    setUp(() {
      ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('invalid address blocks confirmation', () async {
      expect(
        () => container
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: ethereum,
              asset: _assetBalance(chain: ethereum, rawBalance: _oneEth),
              recipient: 'not-an-address',
              amount: '0.1',
            ),
        throwsA(
          isA<TransferDraftValidationException>().having(
            (error) => error.failure,
            'failure',
            TransferDraftValidationFailure.invalidAddress,
          ),
        ),
      );

      expect(container.read(transferDraftControllerProvider).request, isNull);
    });

    test('insufficient balance blocks confirmation', () async {
      expect(
        () => container
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: ethereum,
              asset: _assetBalance(chain: ethereum, rawBalance: _oneEth),
              recipient: '0x2222222222222222222222222222222222222222',
              amount: '1.01',
            ),
        throwsA(
          isA<TransferDraftValidationException>().having(
            (error) => error.failure,
            'failure',
            TransferDraftValidationFailure.insufficientBalance,
          ),
        ),
      );

      expect(container.read(transferDraftControllerProvider).request, isNull);
    });

    test('asset requiring memo blocks confirmation when memo is blank', () {
      expect(
        () => container
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: ethereum,
              asset: _assetBalance(
                chain: ethereum,
                rawBalance: _oneEth,
                requiresMemo: true,
              ),
              recipient: '0x2222222222222222222222222222222222222222',
              amount: '0.1',
              memo: '   ',
            ),
        throwsA(
          isA<TransferDraftValidationException>().having(
            (error) => error.failure,
            'failure',
            TransferDraftValidationFailure.missingMemo,
          ),
        ),
      );

      expect(container.read(transferDraftControllerProvider).request, isNull);
    });

    test('valid native asset draft creates a native transfer request', () {
      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: ethereum,
            asset: _assetBalance(chain: ethereum, rawBalance: _oneEth),
            recipient: '0x3333333333333333333333333333333333333333',
            amount: '0.25',
          );

      expect(request.transactionType, TransactionType.nativeTransfer);
      expect(request.amountInBaseUnits, '250000000000000000');
      expect(container.read(transferDraftControllerProvider).request, request);
    });

    test('valid ERC20 asset draft creates an ERC20 transfer request', () {
      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: ethereum,
            asset: _assetBalance(
              chain: ethereum,
              rawBalance: BigInt.from(123456789),
              contractAddress: _usdcContractAddress,
              symbol: 'USDC',
              name: 'USD Coin',
              decimals: 6,
            ),
            recipient: '0x3333333333333333333333333333333333333333',
            amount: '12.3456',
          );

      expect(request.transactionType, TransactionType.erc20Transfer);
      expect(request.assetSymbol, 'USDC');
      expect(request.amountInBaseUnits, '12345600');
      expect(request.tokenDecimals, 6);
      expect(request.tokenContractAddress, _usdcContractAddress);
      expect(container.read(transferDraftControllerProvider).request, request);
    });

    test('valid TRC20 asset draft creates a TRC20 transfer request', () {
      final tron =
          defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet');

      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: tron,
            asset: _assetBalance(
              chain: tron,
              rawBalance: BigInt.from(123456789),
              contractAddress: _trc20ContractAddress,
              symbol: 'USDT',
              name: 'Tether USD',
              decimals: 6,
            ),
            recipient: _tronRecipient,
            amount: '12.3456',
          );

      expect(request.transactionType, TransactionType.trc20Transfer);
      expect(request.assetSymbol, 'USDT');
      expect(request.amountInBaseUnits, '12345600');
      expect(request.tokenDecimals, 6);
      expect(request.tokenContractAddress, _trc20ContractAddress);
      expect(container.read(transferDraftControllerProvider).request, request);
    });

    test('Sui native draft normalizes recipient and creates a Sui transfer',
        () {
      final sui =
          defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');

      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: sui,
            asset: _assetBalance(
              chain: sui,
              rawBalance: BigInt.from(2000000000),
              decimals: 9,
            ),
            recipient: '  0x2  ',
            amount: '0.1',
          );

      expect(request.chainType, ChainType.sui);
      expect(request.transactionType, TransactionType.suiTransfer);
      expect(
        request.toAddress,
        '0x0000000000000000000000000000000000000000000000000000000000000002',
      );
      expect(request.amountInBaseUnits, '100000000');
      expect(request.tokenDecimals, 9);
      expect(request.tokenContractAddress, isNull);
    });

    test('Sui Coin draft retains the full Move type identifier', () {
      final sui =
          defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
      const coinType = '0xabc::usdc::USDC';

      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: sui,
            asset: _assetBalance(
              chain: sui,
              rawBalance: BigInt.from(2000000),
              contractAddress: coinType,
              symbol: 'USDC',
              name: 'USD Coin',
              decimals: 6,
            ),
            recipient: '0x2',
            amount: '1.25',
          );

      expect(request.transactionType, TransactionType.suiTransfer);
      expect(request.amountInBaseUnits, '1250000');
      expect(request.tokenContractAddress, coinType);
    });

    test('Bitcoin draft rejects addresses with an invalid checksum', () {
      final bitcoin =
          defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');

      expect(
        () => container
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: bitcoin,
              asset: _assetBalance(
                chain: bitcoin,
                rawBalance: BigInt.from(100000000),
                decimals: 8,
              ),
              recipient: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyv',
              amount: '0.1',
            ),
        throwsA(
          isA<TransferDraftValidationException>().having(
            (error) => error.failure,
            'failure',
            TransferDraftValidationFailure.invalidAddress,
          ),
        ),
      );

      expect(container.read(transferDraftControllerProvider).request, isNull);
    });

    test('Bitcoin mainnet draft rejects testnet recipient addresses', () {
      final bitcoin =
          defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');

      for (final recipient in [
        'tb1qxmt9xgewg6mxc4mvnzvrzu4f2v0gy782fydg0w',
        '2N8Z5t3GyPW1hSAEJZqQ1GUkZ9ofoGhgKPf',
      ]) {
        expect(
          () => container
              .read(transferDraftControllerProvider.notifier)
              .prepareRequest(
                chain: bitcoin,
                asset: _assetBalance(
                  chain: bitcoin,
                  rawBalance: BigInt.from(100000000),
                  decimals: 8,
                ),
                recipient: recipient,
                amount: '0.1',
              ),
          throwsA(
            isA<TransferDraftValidationException>().having(
              (error) => error.failure,
              'failure',
              TransferDraftValidationFailure.invalidAddress,
            ),
          ),
        );

        expect(container.read(transferDraftControllerProvider).request, isNull);
      }
    });

    test('valid Bitcoin draft creates a Bitcoin transfer request', () {
      final bitcoin =
          defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');

      final request = container
          .read(transferDraftControllerProvider.notifier)
          .prepareRequest(
            chain: bitcoin,
            asset: _assetBalance(
              chain: bitcoin,
              rawBalance: BigInt.from(100000000),
              decimals: 8,
            ),
            recipient: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
            amount: '0.12345678',
            memo: '  invoice 42  ',
          );

      expect(request.chainType, ChainType.bitcoin);
      expect(request.transactionType, TransactionType.bitcoinTransfer);
      expect(request.assetSymbol, 'BTC');
      expect(request.amountInBaseUnits, '12345678');
      expect(request.tokenDecimals, 8);
      expect(request.memo, 'invoice 42');
      expect(request.tokenContractAddress, isNull);
      expect(container.read(transferDraftControllerProvider).request, request);
    });

    test('Bitcoin draft accepts legacy and Taproot recipient addresses', () {
      final bitcoin =
          defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');

      for (final recipient in [
        '1BoatSLRHtKNngkdXEeobR76b53LETtpyT',
        'bc1ph4lmxwklchcvvh2wchzassw86yvahdt902mpe0velxzuz2c70sps70mzj4',
      ]) {
        final request = container
            .read(transferDraftControllerProvider.notifier)
            .prepareRequest(
              chain: bitcoin,
              asset: _assetBalance(
                chain: bitcoin,
                rawBalance: BigInt.from(100000000),
                decimals: 8,
              ),
              recipient: recipient,
              amount: '0.01',
            );

        expect(request.chainType, ChainType.bitcoin);
        expect(request.toAddress, recipient);
        expect(request.amountInBaseUnits, '1000000');
      }
    });
  });
}

AssetBalance _assetBalance({
  required ChainConfig chain,
  required BigInt rawBalance,
  String? contractAddress,
  String? symbol,
  String? name,
  int decimals = 18,
  bool requiresMemo = false,
}) {
  return AssetBalance(
    chainId: chain.chainId,
    token: TokenInfo(
      chainId: chain.chainId,
      contractAddress: contractAddress,
      symbol: symbol ?? chain.symbol,
      name: name ?? chain.name,
      decimals: decimals,
      source: TokenSource.builtIn,
      isHidden: false,
      requiresMemo: requiresMemo,
    ),
    balance: rawBalance.toString(),
    formattedBalance: '1',
    status: AssetBalanceStatus.loaded,
  );
}

final _oneEth = BigInt.from(10).pow(18);
const _usdcContractAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
const _tronRecipient = 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi';
