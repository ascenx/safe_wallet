import '../../chains/domain/chain_config.dart';
import '../../wallet/domain/wallet_account.dart';
import '../domain/wallet_connect_caip.dart';
import '../domain/wallet_connect_namespace.dart';

WalletConnectCapabilities buildWalletConnectCapabilities({
  required List<ChainConfig> chains,
  required WalletAccount account,
}) {
  final namespaces = <String, WalletConnectNamespaceCapability>{};
  final evmAddress = account.evmAddress.trim();
  if (evmAddress.isNotEmpty) {
    final evmChains = chains
        .where((chain) => chain.chainType == ChainType.evm)
        .map(
          (chain) =>
              Caip2ChainId(namespace: 'eip155', reference: chain.chainId),
        )
        .toSet();
    namespaces['eip155'] = WalletConnectNamespaceCapability(
      chains: Set.unmodifiable(evmChains),
      methods: const {
        'personal_sign',
        'eth_signTypedData_v4',
        'eth_signTransaction',
        'eth_sendTransaction',
      },
      events: const {'accountsChanged', 'chainChanged'},
      accounts: Set.unmodifiable(
        evmChains.map(
          (chain) => Caip10AccountId(chain: chain, address: evmAddress),
        ),
      ),
    );
  }

  final solanaAddress = account.solanaAddress.trim();
  if (solanaAddress.isNotEmpty) {
    final solanaChains = chains
        .where((chain) => chain.chainType == ChainType.solana)
        .map(_solanaCaipChain)
        .whereType<Caip2ChainId>()
        .toSet();
    if (solanaChains.isNotEmpty) {
      namespaces['solana'] = WalletConnectNamespaceCapability(
        chains: Set.unmodifiable(solanaChains),
        methods: const {
          'solana_signMessage',
          'solana_signTransaction',
          'solana_signAllTransactions',
          'solana_signAndSendTransaction',
        },
        events: const {'accountsChanged', 'chainChanged'},
        accounts: Set.unmodifiable(
          solanaChains.map(
            (chain) => Caip10AccountId(chain: chain, address: solanaAddress),
          ),
        ),
      );
    }
  }

  return WalletConnectCapabilities(namespaces: Map.unmodifiable(namespaces));
}

Caip2ChainId? _solanaCaipChain(ChainConfig chain) {
  final reference = switch (chain.chainId) {
    'mainnet-beta' => '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp',
    'devnet' => 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
    'testnet' => '4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z',
    _ => null,
  };
  if (reference == null) {
    return null;
  }
  return Caip2ChainId(namespace: 'solana', reference: reference);
}
