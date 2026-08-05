part of 'dapp_request_controller.dart';

DappPermission _walletConnectPermission(
  DappRpcRequest request,
  WalletAccount account,
  ChainConfig chain,
  String address,
) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return DappPermission(
    id: 'wallet_connect|${request.requestTopic}|${request.id}',
    domain: request.domain,
    walletId: account.id,
    chainId: chain.chainId,
    address: address,
    grantedAt: timestamp,
    lastUsedAt: timestamp,
  );
}

DappEvmTransaction? _transactionFromParams(
  List<Object?> params, {
  required String fallbackFrom,
}) {
  final map = _firstMap(params);
  if (map == null) {
    return null;
  }
  final from = _stringValue(map['from']) ?? fallbackFrom;
  return DappEvmTransaction(
    from: from,
    to: _stringValue(map['to']),
    valueWei: _quantityToBigInt(_stringValue(map['value'])),
    nonce: _quantityToInt(_stringValue(map['nonce'])),
    gasLimit: _quantityToInt(_stringValue(map['gas'] ?? map['gasLimit'])),
    gasPriceWei: _quantityToBigInt(_stringValue(map['gasPrice'])),
    maxFeePerGasWei: _quantityToBigInt(_stringValue(map['maxFeePerGas'])),
    maxPriorityFeePerGasWei: _quantityToBigInt(
      _stringValue(map['maxPriorityFeePerGas']),
    ),
    data: _hexDataToBytes(_stringValue(map['data'] ?? map['input'])),
  );
}

Map<String, Object?>? _firstMap(List<Object?> params) {
  if (params.isEmpty) {
    return null;
  }
  final first = params.first;
  if (first is Map<String, Object?>) {
    return first;
  }
  if (first is Map) {
    return first.cast<String, Object?>();
  }
  return null;
}

String? _stringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

String? _requestedChainId(List<Object?> params) {
  final map = _firstMap(params);
  return map == null ? null : _stringValue(map['chainId']);
}

bool _requestsEthAccountsPermission(List<Object?> params) {
  final map = _firstMap(params);
  return map != null && map.containsKey('eth_accounts');
}

bool _isReadOnlyEvmRpcMethod(String method) {
  return _readOnlyEvmRpcMethods.contains(method);
}

List<Map<String, Object>> _ethAccountsPermissions(Iterable<String> accounts) {
  return [
    {
      'parentCapability': 'eth_accounts',
      'caveats': [
        {'type': 'restrictReturnedAccounts', 'value': accounts.toList()},
      ],
    },
  ];
}

String _personalSignMessage(
  List<Object?> params, {
  required String requestedAddress,
}) {
  if (params.isEmpty) {
    return '';
  }
  for (final value in params) {
    if (value is String &&
        value.toLowerCase() != requestedAddress.toLowerCase()) {
      return value;
    }
  }
  return jsonEncode(params.first);
}

String? _evmAddressFromParams(List<Object?> params) {
  final addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  return params.whereType<String>().where(addressPattern.hasMatch).firstOrNull;
}

Eip712TypedData? _typedDataFromParams(List<Object?> params) {
  for (final value in params) {
    final typedData = Eip712TypedData.tryParse(value);
    if (typedData != null) {
      return typedData;
    }
  }
  return null;
}

String? _typedDataAddress(List<Object?> params) {
  final addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');
  for (final value in params) {
    if (value is String && addressPattern.hasMatch(value)) {
      return value;
    }
  }
  return null;
}

List<int>? _solanaMessageBytes(List<Object?> params) {
  if (params.isEmpty) {
    return null;
  }
  final first = params.first;
  final byteList = _bridgeByteList(first);
  if (byteList != null) {
    return byteList;
  }
  if (first is String) {
    if (first.startsWith('0x')) {
      try {
        return _hexToBytes(first).toList();
      } catch (_) {
        return null;
      }
    }
    return utf8.encode(first);
  }
  return null;
}

List<int>? _solanaTransactionBytes(List<Object?> params) {
  if (params.isEmpty) {
    return null;
  }
  final first = params.first;
  final byteList = _bridgeByteList(first);
  if (byteList != null) {
    return byteList;
  }
  if (first is String) {
    if (first.startsWith('0x')) {
      try {
        return _hexToBytes(first).toList();
      } catch (_) {
        return null;
      }
    }
    try {
      return base64Decode(first);
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<List<int>>? _solanaTransactionsBytes(List<Object?> params) {
  if (params.isEmpty) {
    return null;
  }
  final first = params.first;
  if (first is! List) {
    final transaction = _solanaTransactionBytes(params);
    return transaction == null ? null : [transaction];
  }
  if (first.isEmpty || !first.every((value) => value is List)) {
    final transaction = _bridgeByteList(first);
    return transaction == null ? null : [transaction];
  }
  final transactions = <List<int>>[];
  for (final value in first) {
    final transaction = _bridgeByteList(value);
    if (transaction == null) {
      return null;
    }
    transactions.add(transaction);
  }
  return transactions;
}

List<int>? _bridgeByteList(Object? value) {
  if (value is List) {
    final bytes = <int>[];
    for (final item in value) {
      if (item is int && item >= 0 && item <= 255) {
        bytes.add(item);
      } else if (item is num && item >= 0 && item <= 255) {
        bytes.add(item.toInt());
      } else {
        return null;
      }
    }
    return bytes;
  }
  return null;
}

bool _matchesSuiRequest(Map<String, Object?> payload, _DappSuiContext context) {
  final requestedAddress = _stringValue(payload['account']);
  final requestedChain = _stringValue(payload['chain']);
  final normalizedRequested = requestedAddress == null
      ? null
      : normalizeSuiAddressInput(requestedAddress);
  return normalizedRequested == context.account.suiAddress &&
      requestedChain == context.chain.chainId;
}

List<int>? _suiBytesField(Object? value, {required int maximumLength}) {
  List<int>? bytes = _bridgeByteList(value);
  if (bytes == null && value is String) {
    try {
      bytes = base64Decode(value);
    } on FormatException {
      return null;
    }
  }
  if (bytes == null || bytes.isEmpty || bytes.length > maximumLength) {
    return null;
  }
  return bytes;
}

String? _readableMessage(String message) {
  if (!message.startsWith('0x')) {
    return message;
  }
  try {
    return utf8.decode(_hexToBytes(message), allowMalformed: false);
  } catch (_) {
    return null;
  }
}

String? _readableBytes(List<int> message) {
  try {
    return utf8.decode(message, allowMalformed: false);
  } catch (_) {
    return null;
  }
}

Uint8List _messageBytes(String message) {
  if (message.startsWith('0x')) {
    try {
      return _hexToBytes(message);
    } catch (_) {
      return Uint8List.fromList(utf8.encode(message));
    }
  }
  return Uint8List.fromList(utf8.encode(message));
}

Uint8List? _hexDataToBytes(String? value) {
  if (value == null || value == '0x') {
    return null;
  }
  try {
    return _hexToBytes(value);
  } catch (_) {
    return null;
  }
}

BigInt? _quantityToBigInt(String? value) {
  if (value == null) {
    return null;
  }
  if (value.startsWith('0x')) {
    return BigInt.parse(
      value.substring(2).isEmpty ? '0' : value.substring(2),
      radix: 16,
    );
  }
  return BigInt.tryParse(value);
}

String _formatUnits(BigInt value, int decimals) {
  if (value == BigInt.zero) {
    return '0';
  }
  final negative = value.isNegative;
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final fraction = digits
      .substring(digits.length - decimals)
      .replaceFirst(RegExp(r'0+$'), '');
  final formatted = fraction.isEmpty ? whole : '$whole.$fraction';
  return negative ? '-$formatted' : formatted;
}

int? _quantityToInt(String? value) {
  return _quantityToBigInt(value)?.toInt();
}

String _chainIdToHex(String chainId) {
  final parsed = int.tryParse(chainId);
  if (parsed == null) {
    return chainId;
  }
  return '0x${parsed.toRadixString(16)}';
}

String _rpcChainIdToDecimal(String chainId) {
  if (chainId.startsWith('0x')) {
    return BigInt.parse(chainId.substring(2), radix: 16).toString();
  }
  return chainId;
}

String? _caipReference(String chainId, String expectedNamespace) {
  final parts = chainId.split(':');
  if (parts.length != 2 ||
      parts.first != expectedNamespace ||
      parts.last.isEmpty) {
    return null;
  }
  return parts.last;
}

bool _sameEvmAddress(String left, String right) {
  final pattern = RegExp(r'^0[xX][0-9a-fA-F]{40}$');
  return pattern.hasMatch(left) &&
      pattern.hasMatch(right) &&
      left.substring(2).toLowerCase() == right.substring(2).toLowerCase();
}

Uint8List _hexToBytes(String value) {
  final normalized = value.startsWith('0x') || value.startsWith('0X')
      ? value.substring(2)
      : value;
  if (normalized.length.isOdd) {
    throw const FormatException('Hex input must have an even length');
  }
  return Uint8List.fromList([
    for (var index = 0; index < normalized.length; index += 2)
      int.parse(normalized.substring(index, index + 2), radix: 16),
  ]);
}

String _bytesToHex(List<int> bytes, {bool include0x = false}) {
  final encoded = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return include0x ? '0x$encoded' : encoded;
}

bool _isApprovedAuthorization(DappAuthorizationDecision? decision) {
  return decision == DappAuthorizationDecision.approved ||
      decision == DappAuthorizationDecision.approvedForSession;
}

bool _isPersistentAuthorization(DappAuthorizationDecision? decision) {
  return decision == DappAuthorizationDecision.approved;
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}

const _readOnlyEvmRpcMethods = {
  'eth_blockNumber',
  'eth_call',
  'eth_estimateGas',
  'eth_feeHistory',
  'eth_gasPrice',
  'eth_getBalance',
  'eth_getBlockByHash',
  'eth_getBlockByNumber',
  'eth_getBlockTransactionCountByHash',
  'eth_getBlockTransactionCountByNumber',
  'eth_getCode',
  'eth_getLogs',
  'eth_getStorageAt',
  'eth_getTransactionByBlockHashAndIndex',
  'eth_getTransactionByBlockNumberAndIndex',
  'eth_getTransactionByHash',
  'eth_getTransactionCount',
  'eth_getTransactionReceipt',
  'eth_getUncleByBlockHashAndIndex',
  'eth_getUncleByBlockNumberAndIndex',
  'eth_getUncleCountByBlockHash',
  'eth_getUncleCountByBlockNumber',
  'eth_maxPriorityFeePerGas',
  'eth_protocolVersion',
  'eth_syncing',
  'net_listening',
  'net_peerCount',
  'web3_clientVersion',
  'web3_sha3',
};

const _maximumSuiMessageBytes = 1024 * 1024;
const _maximumSuiTransactionBytes = 2 * 1024 * 1024;
