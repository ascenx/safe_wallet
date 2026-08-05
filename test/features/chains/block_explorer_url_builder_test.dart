import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/block_explorer_url_builder.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';

void main() {
  test('Solana devnet transaction URL preserves the cluster', () {
    expect(
      buildBlockExplorerTransactionUrl(
        chainType: ChainType.solana,
        chainId: 'devnet',
        transactionHash: 'signature',
        blockExplorerUrl: 'https://solscan.io',
      ),
      'https://solscan.io/tx/signature?cluster=devnet',
    );
  });

  test('TRON transaction URL uses the Tronscan hash route', () {
    expect(
      buildBlockExplorerTransactionUrl(
        chainType: ChainType.tron,
        chainId: 'tron-mainnet',
        transactionHash: 'trx-hash',
        blockExplorerUrl: 'https://tronscan.org',
      ),
      'https://tronscan.org/#/transaction/trx-hash',
    );
  });
}
