import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/web3dart.dart' as web3;

final class Eip712TypedData {
  Eip712TypedData._({
    required this.types,
    required this.primaryType,
    required this.domain,
    required this.message,
    required this.json,
  });

  final Map<String, List<Eip712Field>> types;
  final String primaryType;
  final Map<String, Object?> domain;
  final Map<String, Object?> message;
  final Map<String, Object?> json;

  static Eip712TypedData? tryParse(Object? value) {
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is! Map) {
        return null;
      }
      final json = decoded.cast<String, Object?>();
      final rawTypes = json['types'];
      final primaryType = json['primaryType'];
      final rawDomain = json['domain'];
      final rawMessage = json['message'];
      if (rawTypes is! Map ||
          primaryType is! String ||
          primaryType.isEmpty ||
          rawDomain is! Map ||
          rawMessage is! Map) {
        return null;
      }

      final types = <String, List<Eip712Field>>{};
      for (final entry in rawTypes.entries) {
        final typeName = entry.key;
        final rawFields = entry.value;
        if (typeName is! String || typeName.isEmpty || rawFields is! List) {
          return null;
        }
        final fields = <Eip712Field>[];
        for (final rawField in rawFields) {
          if (rawField is! Map) {
            return null;
          }
          final name = rawField['name'];
          final type = rawField['type'];
          if (name is! String ||
              name.isEmpty ||
              type is! String ||
              type.isEmpty) {
            return null;
          }
          fields.add(Eip712Field(name: name, type: type));
        }
        types[typeName] = List.unmodifiable(fields);
      }
      if (!types.containsKey('EIP712Domain') ||
          !types.containsKey(primaryType)) {
        return null;
      }

      return Eip712TypedData._(
        types: Map.unmodifiable(types),
        primaryType: primaryType,
        domain: Map.unmodifiable(rawDomain.cast<String, Object?>()),
        message: Map.unmodifiable(rawMessage.cast<String, Object?>()),
        json: Map.unmodifiable(json),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List signingPayload() {
    final encoder = _Eip712Encoder(types);
    return Uint8List.fromList([
      0x19,
      0x01,
      ...encoder.hashStruct('EIP712Domain', domain),
      ...encoder.hashStruct(primaryType, message),
    ]);
  }

  String displayJson() => const JsonEncoder.withIndent('  ').convert(json);
}

final class Eip712Field {
  const Eip712Field({required this.name, required this.type});

  final String name;
  final String type;
}

final class _Eip712Encoder {
  const _Eip712Encoder(this.types);

  final Map<String, List<Eip712Field>> types;

  Uint8List hashStruct(String type, Map<String, Object?> data) {
    return web3.keccak256(encodeData(type, data));
  }

  Uint8List encodeData(String type, Map<String, Object?> data) {
    final fields = types[type];
    if (fields == null) {
      throw FormatException('Unknown EIP-712 type: $type');
    }
    final encoded = <int>[...web3.keccakUtf8(encodeType(type))];
    for (final field in fields) {
      if (!data.containsKey(field.name)) {
        throw FormatException('Missing EIP-712 field: ${field.name}');
      }
      encoded.addAll(_encodeValue(field.type, data[field.name]));
    }
    return Uint8List.fromList(encoded);
  }

  String encodeType(String primaryType) {
    if (!types.containsKey(primaryType)) {
      throw FormatException('Unknown EIP-712 type: $primaryType');
    }
    final dependencies = <String>{};
    _collectDependencies(primaryType, dependencies);
    dependencies.remove(primaryType);
    final sortedDependencies = dependencies.toList()..sort();
    return [primaryType, ...sortedDependencies].map(_typeDeclaration).join();
  }

  void _collectDependencies(String type, Set<String> dependencies) {
    if (!dependencies.add(type)) {
      return;
    }
    final fields = types[type];
    if (fields == null) {
      return;
    }
    for (final field in fields) {
      final baseType = _baseType(field.type);
      if (types.containsKey(baseType)) {
        _collectDependencies(baseType, dependencies);
      }
    }
  }

  String _typeDeclaration(String type) {
    final fields = types[type];
    if (fields == null) {
      throw FormatException('Unknown EIP-712 type: $type');
    }
    final parameters =
        fields.map((field) => '${field.type} ${field.name}').join(',');
    return '$type($parameters)';
  }

  Uint8List _encodeValue(String type, Object? value) {
    final array = _arrayType(type);
    if (array != null) {
      if (value is! List ||
          (array.length != null && value.length != array.length)) {
        throw FormatException('Invalid EIP-712 array value for $type');
      }
      final encoded = <int>[];
      for (final item in value) {
        encoded.addAll(_encodeValue(array.elementType, item));
      }
      return web3.keccak256(Uint8List.fromList(encoded));
    }

    final fields = types[type];
    if (fields != null) {
      if (value is! Map) {
        throw FormatException('Invalid EIP-712 struct value for $type');
      }
      return hashStruct(type, value.cast<String, Object?>());
    }

    if (type == 'string') {
      if (value is! String) {
        throw FormatException('Invalid EIP-712 string value');
      }
      return web3.keccak256(Uint8List.fromList(utf8.encode(value)));
    }
    if (type == 'bytes') {
      return web3.keccak256(_bytesValue(value));
    }
    if (type == 'bool') {
      if (value is! bool) {
        throw FormatException('Invalid EIP-712 bool value');
      }
      return _encodeUnsigned(value ? BigInt.one : BigInt.zero);
    }
    if (type == 'address') {
      final bytes = _hexBytes(value, expectedLength: 20);
      return _leftPad(bytes, 32);
    }

    final fixedBytesMatch =
        RegExp(r'^bytes([1-9]|[12][0-9]|3[0-2])$').firstMatch(type);
    if (fixedBytesMatch != null) {
      final length = int.parse(fixedBytesMatch.group(1)!);
      return _rightPad(_hexBytes(value, expectedLength: length), 32);
    }

    final integerMatch = RegExp(r'^(u?int)([0-9]*)$').firstMatch(type);
    if (integerMatch != null) {
      final signed = integerMatch.group(1) == 'int';
      final widthText = integerMatch.group(2)!;
      final width = widthText.isEmpty ? 256 : int.parse(widthText);
      if (width < 8 || width > 256 || width % 8 != 0) {
        throw FormatException('Invalid EIP-712 integer type: $type');
      }
      final integer = _integerValue(value);
      if (signed) {
        final limit = BigInt.one << (width - 1);
        if (integer < -limit || integer >= limit) {
          throw FormatException('EIP-712 integer is out of range for $type');
        }
        final encoded =
            integer.isNegative ? (BigInt.one << 256) + integer : integer;
        return _encodeUnsigned(encoded);
      }
      final limit = BigInt.one << width;
      if (integer.isNegative || integer >= limit) {
        throw FormatException('EIP-712 integer is out of range for $type');
      }
      return _encodeUnsigned(integer);
    }

    throw FormatException('Unsupported EIP-712 type: $type');
  }
}

({String elementType, int? length})? _arrayType(String type) {
  final match = RegExp(r'^(.*)\[([0-9]*)\]$').firstMatch(type);
  if (match == null || match.group(1)!.isEmpty) {
    return null;
  }
  final lengthText = match.group(2)!;
  return (
    elementType: match.group(1)!,
    length: lengthText.isEmpty ? null : int.parse(lengthText),
  );
}

String _baseType(String type) {
  var result = type;
  while (true) {
    final array = _arrayType(result);
    if (array == null) {
      return result;
    }
    result = array.elementType;
  }
}

Uint8List _bytesValue(Object? value) {
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  return _hexBytes(value);
}

Uint8List _hexBytes(Object? value, {int? expectedLength}) {
  if (value is! String || !value.startsWith('0x')) {
    throw FormatException('Invalid EIP-712 hex value');
  }
  final bytes = web3.hexToBytes(value);
  if (expectedLength != null && bytes.length != expectedLength) {
    throw FormatException('Invalid EIP-712 hex value length');
  }
  return bytes;
}

BigInt _integerValue(Object? value) {
  if (value is int) {
    return BigInt.from(value);
  }
  if (value is String) {
    return BigInt.parse(
      value.startsWith('0x') ? value.substring(2) : value,
      radix: value.startsWith('0x') ? 16 : 10,
    );
  }
  throw FormatException('Invalid EIP-712 integer value');
}

Uint8List _encodeUnsigned(BigInt value) {
  return _leftPad(web3.unsignedIntToBytes(value), 32);
}

Uint8List _leftPad(List<int> value, int length) {
  if (value.length > length) {
    throw const FormatException('EIP-712 value exceeds 32 bytes');
  }
  return Uint8List.fromList([
    ...List<int>.filled(length - value.length, 0),
    ...value,
  ]);
}

Uint8List _rightPad(List<int> value, int length) {
  if (value.length > length) {
    throw const FormatException('EIP-712 value exceeds 32 bytes');
  }
  return Uint8List.fromList([
    ...value,
    ...List<int>.filled(length - value.length, 0),
  ]);
}
