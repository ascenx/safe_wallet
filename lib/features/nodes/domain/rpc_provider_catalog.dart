import 'rpc_node.dart';

enum RpcProviderChainType {
  evm,
  bitcoin,
  tron,
  solana,
  sui,
}

final class RpcProviderPreset {
  const RpcProviderPreset({
    required this.provider,
    required this.url,
    required this.credentialMode,
    this.credentialParameter,
  });

  final RpcProvider provider;
  final String url;
  final RpcCredentialMode credentialMode;
  final String? credentialParameter;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RpcProviderPreset &&
            other.provider == provider &&
            other.url == url &&
            other.credentialMode == credentialMode &&
            other.credentialParameter == credentialParameter;
  }

  @override
  int get hashCode => Object.hash(
        provider,
        url,
        credentialMode,
        credentialParameter,
      );
}

abstract final class RpcProviderCatalog {
  static RpcProviderPreset? forChain({
    required RpcProvider provider,
    required RpcProviderChainType chainType,
    required String chainId,
    String? endpointUrl,
  }) {
    return switch (provider) {
      RpcProvider.helius => _helius(chainType, chainId),
      RpcProvider.quickNode => _quickNode(endpointUrl),
      RpcProvider.alchemy => _alchemy(chainType, chainId),
      RpcProvider.infura => _infura(chainType, chainId),
      RpcProvider.tronGrid => _tronGrid(chainType),
      RpcProvider.public || RpcProvider.custom => null,
    };
  }

  static RpcProviderPreset? _helius(
    RpcProviderChainType chainType,
    String chainId,
  ) {
    if (chainType != RpcProviderChainType.solana) {
      return null;
    }
    final host = switch (chainId) {
      'mainnet-beta' => 'mainnet.helius-rpc.com',
      'devnet' => 'devnet.helius-rpc.com',
      _ => null,
    };
    if (host == null) {
      return null;
    }
    return RpcProviderPreset(
      provider: RpcProvider.helius,
      url: 'https://$host/',
      credentialMode: RpcCredentialMode.queryParameter,
      credentialParameter: 'api-key',
    );
  }

  static RpcProviderPreset? _quickNode(String? endpointUrl) {
    final endpoint = endpointUrl == null ? null : Uri.tryParse(endpointUrl);
    if (endpoint == null ||
        !endpoint.hasAuthority ||
        (endpoint.scheme != 'https' && endpoint.scheme != 'http')) {
      return null;
    }
    return RpcProviderPreset(
      provider: RpcProvider.quickNode,
      url: endpoint.replace(path: '/', query: null, fragment: null).toString(),
      credentialMode: RpcCredentialMode.fullEndpoint,
    );
  }

  static RpcProviderPreset? _alchemy(
    RpcProviderChainType chainType,
    String chainId,
  ) {
    if (chainType != RpcProviderChainType.evm) {
      return null;
    }
    final network = switch (chainId) {
      '1' => 'eth-mainnet',
      '10' => 'opt-mainnet',
      '56' => 'bnb-mainnet',
      '137' => 'polygon-mainnet',
      '42161' => 'arb-mainnet',
      '8453' => 'base-mainnet',
      _ => null,
    };
    if (network == null) {
      return null;
    }
    return RpcProviderPreset(
      provider: RpcProvider.alchemy,
      url: 'https://$network.g.alchemy.com/v2',
      credentialMode: RpcCredentialMode.pathSegment,
    );
  }

  static RpcProviderPreset? _infura(
    RpcProviderChainType chainType,
    String chainId,
  ) {
    if (chainType != RpcProviderChainType.evm) {
      return null;
    }
    final network = switch (chainId) {
      '1' => 'mainnet',
      '10' => 'optimism-mainnet',
      '137' => 'polygon-mainnet',
      '42161' => 'arbitrum-mainnet',
      '8453' => 'base-mainnet',
      _ => null,
    };
    if (network == null) {
      return null;
    }
    return RpcProviderPreset(
      provider: RpcProvider.infura,
      url: 'https://$network.infura.io/v3',
      credentialMode: RpcCredentialMode.pathSegment,
    );
  }

  static RpcProviderPreset? _tronGrid(RpcProviderChainType chainType) {
    if (chainType != RpcProviderChainType.tron) {
      return null;
    }
    return const RpcProviderPreset(
      provider: RpcProvider.tronGrid,
      url: 'https://api.trongrid.io',
      credentialMode: RpcCredentialMode.header,
      credentialParameter: 'TRON-PRO-API-KEY',
    );
  }
}
