import '../../features/chains/domain/chain_config.dart';
import 'bitcoin_address.dart';
import 'evm_address.dart';
import 'sui_address.dart';

final class ParsedWalletAddress {
  const ParsedWalletAddress({
    required this.address,
    required this.chainType,
    this.decimal,
    this.symbol,
    this.token,
    this.contractAddress,
    this.chainName,
    this.memo,
    this.label,
    this.amount,
    this.amountBaseUnits,
    this.evmChainId,
    this.bitcoinNetwork,
  });

  final String address;
  final ChainType chainType;
  final String? decimal;
  final String? symbol;
  final String? token;
  final String? contractAddress;
  final String? chainName;
  final String? memo;
  final String? label;
  final String? amount;
  final String? amountBaseUnits;
  final String? evmChainId;
  final BitcoinAddressNetwork? bitcoinNetwork;

  String? get transferContractAddress {
    final contract = contractAddress;
    if (contract != null && _isEvmAddress(contract)) {
      return contract;
    }
    final tokenAddress = token;
    if (tokenAddress != null && _isEvmAddress(tokenAddress)) {
      return tokenAddress;
    }
    return null;
  }
}

ParsedWalletAddress? parseWalletAddress(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme == 'ethereum' || scheme == 'eth') {
    return _parseEip681Address(trimmed, uri);
  }

  final parameters = _knownParameters(uri?.queryParameters ?? const {});
  final candidate = switch (scheme) {
    'bitcoin' || 'btc' => uri!.path.isEmpty ? uri.host : uri.path,
    'solana' => uri!.path.isEmpty ? uri.host : uri.path,
    'sui' => uri!.path.isEmpty ? uri.host : uri.path,
    _ => trimmed,
  };
  final address = candidate.split('?').first;

  if (scheme == 'bitcoin' || scheme == 'btc') {
    final network = bitcoinAddressNetwork(address);
    return network != null
        ? _parsed(
            address: address,
            chainType: ChainType.bitcoin,
            parameters: parameters,
            bitcoinNetwork: network,
          )
        : null;
  }

  if (scheme == 'solana') {
    return _isSolanaAddress(address)
        ? _parsed(
            address: address,
            chainType: ChainType.solana,
            parameters: parameters,
          )
        : null;
  }

  if (scheme == 'sui') {
    final normalized = normalizeSuiAddressInput(address);
    return normalized == null
        ? null
        : _parsed(
            address: normalized,
            chainType: ChainType.sui,
            parameters: parameters,
          );
  }

  if (_isEvmAddress(address)) {
    return _parsed(
      address: address,
      chainType: ChainType.evm,
      parameters: parameters,
    );
  }
  final bitcoinNetwork = bitcoinAddressNetwork(address);
  if (bitcoinNetwork != null) {
    return _parsed(
      address: address,
      chainType: ChainType.bitcoin,
      parameters: parameters,
      bitcoinNetwork: bitcoinNetwork,
    );
  }
  if (_isSolanaAddress(address)) {
    return _parsed(
      address: address,
      chainType: ChainType.solana,
      parameters: parameters,
    );
  }
  final normalizedSuiAddress = normalizeSuiAddressInput(address);
  final rawHex = address.startsWith('0x') || address.startsWith('0X')
      ? address.substring(2)
      : address;
  if (normalizedSuiAddress != null && rawHex.length > 40) {
    return _parsed(
      address: normalizedSuiAddress,
      chainType: ChainType.sui,
      parameters: parameters,
    );
  }
  return null;
}

ParsedWalletAddress _parsed({
  required String address,
  required ChainType chainType,
  required _KnownAddressParameters parameters,
  BitcoinAddressNetwork? bitcoinNetwork,
}) {
  return ParsedWalletAddress(
    address: address,
    chainType: chainType,
    decimal: parameters.decimal,
    symbol: parameters.symbol,
    token: parameters.token,
    contractAddress: parameters.contractAddress,
    chainName: parameters.chainName,
    memo: parameters.memo,
    label: parameters.label,
    amount: parameters.amount,
    bitcoinNetwork: bitcoinNetwork,
  );
}

ParsedWalletAddress? _parseEip681Address(String value, Uri? uri) {
  final separator = value.indexOf(':');
  if (separator < 0 || separator == value.length - 1) {
    return null;
  }

  final payload = value.substring(separator + 1);
  final targetAndFunction = payload.split('?').first;
  final segments = targetAndFunction.split('/');
  final targetParts = segments.first.split('@');
  final target = targetParts.first;
  final chainId = targetParts.length > 1
      ? _normalizedEvmChainId(targetParts[1])
      : null;
  if (targetParts.length > 1 && chainId == null) {
    return null;
  }
  final functionName = segments.length > 1 ? segments[1].toLowerCase() : null;
  final queryParameters = uri?.queryParameters ?? const <String, String>{};
  final parameters = _knownParameters(
    queryParameters,
    includeValueAsAmount: false,
  );

  final parameterAddress = uri?.queryParameters['address'];
  if (functionName == 'transfer' &&
      _isEvmAddress(target) &&
      parameterAddress != null &&
      _isEvmAddress(parameterAddress)) {
    final amountBaseUnits = _nonNegativeInteger(queryParameters['uint256']);
    if (queryParameters.containsKey('uint256') && amountBaseUnits == null) {
      return null;
    }
    return ParsedWalletAddress(
      address: parameterAddress,
      chainType: ChainType.evm,
      decimal: parameters.decimal,
      symbol: parameters.symbol,
      token: parameters.token,
      contractAddress: parameters.contractAddress ?? target,
      chainName: parameters.chainName,
      memo: parameters.memo,
      label: parameters.label,
      amount: parameters.amount,
      amountBaseUnits: amountBaseUnits,
      evmChainId: chainId,
    );
  }

  if (_isEvmAddress(target)) {
    final valueAmount = _eip681NativeAmount(queryParameters['value']);
    if (queryParameters.containsKey('value') && valueAmount == null) {
      return null;
    }
    return ParsedWalletAddress(
      address: target,
      chainType: ChainType.evm,
      decimal: parameters.decimal,
      symbol: parameters.symbol,
      token: parameters.token,
      contractAddress: parameters.contractAddress,
      chainName: parameters.chainName,
      memo: parameters.memo,
      label: parameters.label,
      amount: parameters.amount ?? valueAmount,
      evmChainId: chainId,
    );
  }

  return null;
}

_KnownAddressParameters _knownParameters(
  Map<String, String> parameters, {
  bool includeValueAsAmount = true,
}) {
  return _KnownAddressParameters(
    decimal: _nonBlank(parameters['decimal'] ?? parameters['decimals']),
    symbol: _nonBlank(parameters['symbol']),
    token: _nonBlank(parameters['token']),
    contractAddress: _nonBlank(parameters['contractAddress']),
    chainName: _nonBlank(parameters['chainName']),
    memo: _nonBlank(parameters['memo']),
    label: _nonBlank(parameters['label']),
    amount: _amountParameter(parameters, includeValue: includeValueAsAmount),
  );
}

String? _amountParameter(
  Map<String, String> parameters, {
  required bool includeValue,
}) {
  return _nonBlank(parameters['amount']) ??
      (includeValue ? _nonBlank(parameters['value']) : null);
}

String? _normalizedEvmChainId(String value) {
  final parsed = BigInt.tryParse(value.trim());
  if (parsed == null || parsed <= BigInt.zero) {
    return null;
  }
  return parsed.toString();
}

String? _nonNegativeInteger(String? value) {
  final normalized = _nonBlank(value);
  if (normalized == null) {
    return null;
  }
  final parsed = BigInt.tryParse(normalized);
  if (parsed == null || parsed.isNegative) {
    return null;
  }
  return parsed.toString();
}

String? _eip681NativeAmount(String? value) {
  final baseUnits = _nonNegativeInteger(value);
  if (baseUnits == null) {
    return null;
  }
  return _formatBaseUnits(BigInt.parse(baseUnits), 18);
}

String _formatBaseUnits(BigInt value, int decimals) {
  if (decimals == 0) {
    return value.toString();
  }
  final base = BigInt.from(10).pow(decimals);
  final whole = value ~/ base;
  final fraction = (value % base).toString().padLeft(decimals, '0');
  final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (trimmedFraction.isEmpty) {
    return whole.toString();
  }
  return '$whole.$trimmedFraction';
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

final class _KnownAddressParameters {
  const _KnownAddressParameters({
    required this.decimal,
    required this.symbol,
    required this.token,
    required this.contractAddress,
    required this.chainName,
    required this.memo,
    required this.label,
    required this.amount,
  });

  final String? decimal;
  final String? symbol;
  final String? token;
  final String? contractAddress;
  final String? chainName;
  final String? memo;
  final String? label;
  final String? amount;
}

bool _isEvmAddress(String value) {
  return isValidEvmAddressInput(value);
}

bool _isSolanaAddress(String value) {
  return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value);
}
