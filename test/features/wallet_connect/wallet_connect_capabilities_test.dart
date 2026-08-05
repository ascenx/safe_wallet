import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_capabilities.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';

void main() {
  final account = WalletAccount(
    id: 'wallet-1',
    name: 'Main Wallet',
    evmAddress: '0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc',
    solanaAddress: '11111111111111111111111111111111',
    btcAddress: 'bc1qexample',
    tronAddress: 'TExample',
    suiAddress: '0x1234',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('builds EVM accounts for every available EVM chain', () {
    final capabilities = buildWalletConnectCapabilities(
      chains: defaultChains,
      account: account,
    );
    final evm = capabilities.namespaces['eip155']!;

    expect(
      evm.chains,
      containsAll({
        const Caip2ChainId(namespace: 'eip155', reference: '1'),
        const Caip2ChainId(namespace: 'eip155', reference: '56'),
      }),
    );
    expect(
      evm.accounts.map((value) => value.toString()),
      contains('eip155:56:${account.evmAddress}'),
    );
    expect(evm.methods, contains('personal_sign'));
    expect(evm.methods, contains('eth_signTypedData_v4'));
    expect(evm.methods, contains('eth_sendTransaction'));
  });

  test(
    'uses official Solana CAIP references and does not invent other chains',
    () {
      final capabilities = buildWalletConnectCapabilities(
        chains: defaultChains,
        account: account,
      );
      final solana = capabilities.namespaces['solana']!;

      expect(
        solana.chains,
        containsAll({
          const Caip2ChainId(
            namespace: 'solana',
            reference: '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp',
          ),
          const Caip2ChainId(
            namespace: 'solana',
            reference: 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
          ),
        }),
      );
      expect(solana.methods, contains('solana_signAllTransactions'));
      expect(capabilities.namespaces, isNot(contains('sui')));
      expect(capabilities.namespaces, isNot(contains('tron')));
      expect(capabilities.namespaces, isNot(contains('bip122')));
    },
  );
}
