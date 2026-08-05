import 'dart:convert';
import 'dart:typed_data';

import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

final class EvmContractAbi {
  EvmContractAbi._(this.functions);

  factory EvmContractAbi.parse(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) {
        throw const FormatException('ABI must be a JSON array');
      }
      final functionEntries = decoded
          .whereType<Map<String, dynamic>>()
          .where((entry) => entry['type'] == 'function')
          .toList(growable: false);
      if (functionEntries.isEmpty) {
        throw const FormatException('ABI contains no callable functions');
      }
      final parsedAbi = web3.ContractAbi.fromJson(
        jsonEncode(functionEntries),
        'AdvancedContract',
      );
      final parsedFunctions = parsedAbi.functions
          .where((function) => !function.isConstructor && !function.isDefault)
          .toList(growable: false);
      if (parsedFunctions.length != functionEntries.length) {
        throw const FormatException('ABI functions could not be parsed');
      }
      return EvmContractAbi._([
        for (var index = 0; index < parsedFunctions.length; index += 1)
          EvmContractFunction._(
            parsedFunctions[index],
            functionEntries[index],
          ),
      ]);
    } on EvmContractAbiException {
      rethrow;
    } catch (error) {
      throw EvmContractAbiException(error.toString());
    }
  }

  static EvmContractFunction manualFunction({
    required String signature,
    required String outputTypes,
    required bool isRead,
    bool payable = false,
  }) {
    final match = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)\((.*)\)$')
        .firstMatch(signature.trim());
    if (match == null) {
      throw const EvmContractAbiException('Invalid function signature');
    }
    final inputTypes = _splitTopLevel(match.group(2)!.trim());
    final outputs = _splitTopLevel(outputTypes.trim());
    final abi = jsonEncode([
      {
        'type': 'function',
        'name': match.group(1),
        'stateMutability':
            isRead ? 'view' : (payable ? 'payable' : 'nonpayable'),
        'inputs': [
          for (var index = 0; index < inputTypes.length; index += 1)
            {'name': 'arg$index', 'type': inputTypes[index]},
        ],
        'outputs': [
          for (var index = 0; index < outputs.length; index += 1)
            {'name': 'result$index', 'type': outputs[index]},
        ],
      },
    ]);
    return EvmContractAbi.parse(abi).functions.single;
  }

  static final erc20 = EvmContractAbi.parse(_erc20Abi);
  static final erc721 = EvmContractAbi.parse(_erc721Abi);
  static final erc1155 = EvmContractAbi.parse(_erc1155Abi);

  final List<EvmContractFunction> functions;

  List<EvmContractFunction> get readFunctions =>
      functions.where((function) => function.isRead).toList(growable: false);

  List<EvmContractFunction> get writeFunctions =>
      functions.where((function) => !function.isRead).toList(growable: false);
}

final class EvmContractFunction {
  EvmContractFunction._(
    this._function,
    Map<String, dynamic> source,
  )   : inputs = _parameters(source['inputs']),
        outputs = _parameters(source['outputs']);

  final web3.ContractFunction _function;
  final List<EvmContractParameter> inputs;
  final List<EvmContractParameter> outputs;

  String get name => _function.name;
  String get signature => _function.encodeName();
  bool get isRead => _function.isConstant;
  bool get isPayable => _function.mutability == web3.StateMutability.payable;

  String encodeCall(List<String> values) {
    if (values.length != inputs.length) {
      throw const EvmContractAbiException('Argument count does not match ABI');
    }
    try {
      final parsed = <Object?>[
        for (var index = 0; index < inputs.length; index += 1)
          inputs[index].parse(values[index]),
      ];
      return web3.bytesToHex(
        _function.encodeCall(parsed),
        include0x: true,
        padToEvenLength: true,
      );
    } catch (error) {
      throw EvmContractAbiException(error.toString());
    }
  }

  List<String> decodeResult(String encodedResult) {
    try {
      return _function
          .decodeReturnValues(encodedResult)
          .map(formatEvmContractValue)
          .toList(growable: false);
    } catch (error) {
      throw EvmContractAbiException(error.toString());
    }
  }
}

final class EvmContractParameter {
  const EvmContractParameter({
    required this.name,
    required this.type,
    this.components = const [],
  });

  final String name;
  final String type;
  final List<EvmContractParameter> components;

  Object? parse(String input) {
    final value = input.trim();
    if (type.endsWith(']')) {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        throw const FormatException('Array argument must be a JSON array');
      }
      final itemType = type.substring(0, type.lastIndexOf('['));
      final itemParameter = EvmContractParameter(
        name: name,
        type: itemType,
        components: components,
      );
      return decoded
          .map((item) => itemParameter.parse(_jsonInput(item)))
          .toList(growable: false);
    }
    if (type == 'tuple') {
      final decoded = jsonDecode(value);
      if (decoded is! List || decoded.length != components.length) {
        throw const FormatException(
          'Tuple argument must be a JSON array matching its components',
        );
      }
      return [
        for (var index = 0; index < components.length; index += 1)
          components[index].parse(_jsonInput(decoded[index])),
      ];
    }
    if (type == 'address') {
      return wallet.EthereumAddress.fromHex(value);
    }
    if (type.startsWith('uint') || type.startsWith('int')) {
      return value.startsWith('0x')
          ? BigInt.parse(value.substring(2), radix: 16)
          : BigInt.parse(value);
    }
    if (type == 'bool') {
      return switch (value.toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => throw const FormatException('Boolean must be true or false'),
      };
    }
    if (type == 'bytes' || type.startsWith('bytes') || type == 'function') {
      final normalized = value.startsWith('0x') ? value.substring(2) : value;
      return Uint8List.fromList(web3.hexToBytes(normalized));
    }
    if (type == 'string') {
      return input;
    }
    throw FormatException('Unsupported ABI type: $type');
  }
}

final class EvmContractAbiException implements Exception {
  const EvmContractAbiException(this.message);

  final String message;

  @override
  String toString() => message;
}

String formatEvmContractValue(Object? value) {
  return switch (value) {
    null => 'null',
    final BigInt number => number.toString(),
    final wallet.EthereumAddress address => address.eip55With0x,
    final Uint8List bytes =>
      web3.bytesToHex(bytes, include0x: true, padToEvenLength: true),
    final List values => '[${values.map(formatEvmContractValue).join(', ')}]',
    _ => value.toString(),
  };
}

List<EvmContractParameter> _parameters(Object? source) {
  if (source is! List) {
    return const [];
  }
  return source.whereType<Map<String, dynamic>>().map((entry) {
    return EvmContractParameter(
      name: (entry['name'] as String?) ?? '',
      type: entry['type'] as String,
      components: _parameters(entry['components']),
    );
  }).toList(growable: false);
}

String _jsonInput(Object? value) {
  return switch (value) {
    final String text => text,
    _ => jsonEncode(value),
  };
}

List<String> _splitTopLevel(String value) {
  if (value.isEmpty) {
    return const [];
  }
  final result = <String>[];
  var parentheses = 0;
  var brackets = 0;
  var start = 0;
  for (var index = 0; index < value.length; index += 1) {
    final character = value[index];
    if (character == '(') {
      parentheses += 1;
    } else if (character == ')') {
      parentheses -= 1;
    } else if (character == '[') {
      brackets += 1;
    } else if (character == ']') {
      brackets -= 1;
    } else if (character == ',' && parentheses == 0 && brackets == 0) {
      result.add(value.substring(start, index).trim());
      start = index + 1;
    }
  }
  result.add(value.substring(start).trim());
  if (result.any((item) => item.isEmpty)) {
    throw const EvmContractAbiException('ABI type cannot be empty');
  }
  return result;
}

const _erc20Abi = '''
[
  {"type":"function","name":"name","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"type":"function","name":"symbol","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"type":"function","name":"decimals","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint8"}]},
  {"type":"function","name":"totalSupply","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"balanceOf","stateMutability":"view","inputs":[{"name":"account","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"allowance","stateMutability":"view","inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"transfer","stateMutability":"nonpayable","inputs":[{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
  {"type":"function","name":"approve","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
  {"type":"function","name":"transferFrom","stateMutability":"nonpayable","inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"amount","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]}
]
''';

const _erc721Abi = '''
[
  {"type":"function","name":"name","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"type":"function","name":"symbol","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"string"}]},
  {"type":"function","name":"balanceOf","stateMutability":"view","inputs":[{"name":"owner","type":"address"}],"outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"ownerOf","stateMutability":"view","inputs":[{"name":"tokenId","type":"uint256"}],"outputs":[{"name":"","type":"address"}]},
  {"type":"function","name":"getApproved","stateMutability":"view","inputs":[{"name":"tokenId","type":"uint256"}],"outputs":[{"name":"","type":"address"}]},
  {"type":"function","name":"isApprovedForAll","stateMutability":"view","inputs":[{"name":"owner","type":"address"},{"name":"operator","type":"address"}],"outputs":[{"name":"","type":"bool"}]},
  {"type":"function","name":"approve","stateMutability":"nonpayable","inputs":[{"name":"to","type":"address"},{"name":"tokenId","type":"uint256"}],"outputs":[]},
  {"type":"function","name":"setApprovalForAll","stateMutability":"nonpayable","inputs":[{"name":"operator","type":"address"},{"name":"approved","type":"bool"}],"outputs":[]},
  {"type":"function","name":"transferFrom","stateMutability":"nonpayable","inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"tokenId","type":"uint256"}],"outputs":[]},
  {"type":"function","name":"safeTransferFrom","stateMutability":"nonpayable","inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"tokenId","type":"uint256"}],"outputs":[]}
]
''';

const _erc1155Abi = '''
[
  {"type":"function","name":"balanceOf","stateMutability":"view","inputs":[{"name":"account","type":"address"},{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"uint256"}]},
  {"type":"function","name":"balanceOfBatch","stateMutability":"view","inputs":[{"name":"accounts","type":"address[]"},{"name":"ids","type":"uint256[]"}],"outputs":[{"name":"","type":"uint256[]"}]},
  {"type":"function","name":"isApprovedForAll","stateMutability":"view","inputs":[{"name":"account","type":"address"},{"name":"operator","type":"address"}],"outputs":[{"name":"","type":"bool"}]},
  {"type":"function","name":"uri","stateMutability":"view","inputs":[{"name":"id","type":"uint256"}],"outputs":[{"name":"","type":"string"}]},
  {"type":"function","name":"setApprovalForAll","stateMutability":"nonpayable","inputs":[{"name":"operator","type":"address"},{"name":"approved","type":"bool"}],"outputs":[]},
  {"type":"function","name":"safeTransferFrom","stateMutability":"nonpayable","inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"id","type":"uint256"},{"name":"amount","type":"uint256"},{"name":"data","type":"bytes"}],"outputs":[]},
  {"type":"function","name":"safeBatchTransferFrom","stateMutability":"nonpayable","inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"ids","type":"uint256[]"},{"name":"amounts","type":"uint256[]"},{"name":"data","type":"bytes"}],"outputs":[]}
]
''';
