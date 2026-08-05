import '../../features/chains/domain/chain_config.dart';
import 'sui_address.dart';

String receiveQrPayloadForChain({
  required ChainType chainType,
  required String address,
  String? chainId,
  String? decimal,
  String? symbol,
  String? token,
  String? contractAddress,
  String? chainName,
  String? memo,
  String? label,
  String? amount,
}) {
  return switch (chainType) {
    ChainType.evm => _evmReceiveQrPayload(
        address: address,
        chainId: chainId,
        decimal: decimal,
        symbol: symbol,
        token: token,
        contractAddress: contractAddress,
        chainName: chainName,
        memo: memo,
        label: label,
        amount: amount,
      ),
    ChainType.solana => _solanaReceiveQrPayload(
        address: address,
        amount: amount,
      ),
    ChainType.bitcoin => _bitcoinReceiveQrPayload(
        address: address,
        amount: amount,
      ),
    ChainType.tron => address,
    ChainType.sui => normalizeSuiAddressInput(address) ?? address,
  };
}

String _evmReceiveQrPayload({
  required String address,
  required String? chainId,
  required String? decimal,
  required String? symbol,
  required String? token,
  required String? contractAddress,
  required String? chainName,
  required String? memo,
  required String? label,
  required String? amount,
}) {
  final trimmedChainId = chainId?.trim();
  final base = trimmedChainId == null || trimmedChainId.isEmpty
      ? 'ethereum:$address'
      : 'ethereum:$address@$trimmedChainId';
  return _withKnownParameters(
    base,
    {
      'decimal': decimal,
      'symbol': symbol,
      'token': token,
      'contractAddress': contractAddress,
      'chainName': chainName,
      'memo': memo,
      'label': label,
      'amount': amount,
    },
  );
}

String _solanaReceiveQrPayload({
  required String address,
  required String? amount,
}) {
  final trimmedAmount = _nonBlank(amount);
  if (trimmedAmount == null) {
    return address;
  }
  return _withKnownParameters(
    'solana:$address',
    {'amount': trimmedAmount},
  );
}

String _bitcoinReceiveQrPayload({
  required String address,
  required String? amount,
}) {
  final trimmedAmount = _nonBlank(amount);
  if (trimmedAmount == null) {
    return address;
  }
  return _withKnownParameters(
    'bitcoin:$address',
    {'amount': trimmedAmount},
  );
}

String _withKnownParameters(String value, Map<String, String?> parameters) {
  final queryParameters = <String, String>{};
  for (final entry in parameters.entries) {
    final parameter = _nonBlank(entry.value);
    if (parameter != null) {
      queryParameters[entry.key] = parameter;
    }
  }
  if (queryParameters.isEmpty) {
    return value;
  }
  return '$value?${Uri(queryParameters: queryParameters).query}';
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
