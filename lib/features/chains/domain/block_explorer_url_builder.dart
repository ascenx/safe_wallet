import 'chain_config.dart';

String? buildBlockExplorerAddressUrl({
  required ChainType chainType,
  required String chainId,
  required String address,
  String? blockExplorerUrl,
}) {
  final normalizedAddress = address.trim();
  if (normalizedAddress.isEmpty) {
    return null;
  }

  return switch (chainType) {
    ChainType.evm => _pathUrl(blockExplorerUrl, [
      'address',
      normalizedAddress,
    ], fragment: 'transactions'),
    ChainType.bitcoin => _pathUrl(
      blockExplorerUrl ?? 'https://blockstream.info',
      ['address', normalizedAddress],
    ),
    ChainType.tron => _tronAddressUrl(
      blockExplorerUrl ?? 'https://tronscan.org',
      normalizedAddress,
    ),
    ChainType.solana => Uri.https(
      'solscan.io',
      '/account/$normalizedAddress',
      chainId == 'mainnet-beta' ? null : {'cluster': chainId},
    ).toString(),
    ChainType.sui => _pathUrl(blockExplorerUrl, [
      'account',
      normalizedAddress,
      'tx-blocks',
    ]),
  };
}

String? buildBlockExplorerTransactionUrl({
  required ChainType chainType,
  required String chainId,
  required String transactionHash,
  String? blockExplorerUrl,
}) {
  final normalizedHash = transactionHash.trim();
  if (normalizedHash.isEmpty) {
    return null;
  }
  return switch (chainType) {
    ChainType.evm => _pathUrl(blockExplorerUrl, ['tx', normalizedHash]),
    ChainType.bitcoin => _pathUrl(
      blockExplorerUrl ?? 'https://blockstream.info',
      ['tx', normalizedHash],
    ),
    ChainType.tron => _tronTransactionUrl(
      blockExplorerUrl ?? 'https://tronscan.org',
      normalizedHash,
    ),
    ChainType.solana => Uri.https(
      'solscan.io',
      '/tx/$normalizedHash',
      chainId == 'mainnet-beta' ? null : {'cluster': chainId},
    ).toString(),
    ChainType.sui => _pathUrl(blockExplorerUrl, ['txblock', normalizedHash]),
  };
}

String? _pathUrl(
  String? baseUrl,
  List<String> pathSegments, {
  String? fragment,
}) {
  final base = baseUrl == null ? null : Uri.tryParse(baseUrl);
  if (base == null || !base.hasAuthority) {
    return null;
  }
  return base
      .replace(
        pathSegments: [
          ...base.pathSegments.where((segment) => segment.isNotEmpty),
          ...pathSegments,
        ],
        query: null,
        fragment: fragment,
      )
      .toString();
}

String? _tronAddressUrl(String baseUrl, String address) {
  final base = Uri.tryParse(baseUrl);
  if (base == null || !base.hasAuthority) {
    return null;
  }
  final normalizedBase = base.replace(query: null, fragment: null).toString();
  final separator = normalizedBase.endsWith('/') ? '' : '/';
  return '$normalizedBase$separator#/address/'
      '${Uri.encodeComponent(address)}/transfers';
}

String? _tronTransactionUrl(String baseUrl, String transactionHash) {
  final base = Uri.tryParse(baseUrl);
  if (base == null || !base.hasAuthority) {
    return null;
  }
  final normalizedBase = base.replace(query: null, fragment: null).toString();
  final separator = normalizedBase.endsWith('/') ? '' : '/';
  return '$normalizedBase$separator#/transaction/'
      '${Uri.encodeComponent(transactionHash)}';
}
