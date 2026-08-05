import 'dart:convert';

final class StorageJsonCodec {
  const StorageJsonCodec();

  String encode(Map<String, Object?> value) {
    return jsonEncode(value);
  }

  Map<String, Object?> decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('Stored JSON value is not an object');
    }

    return decoded.cast<String, Object?>();
  }

  T? tryDecode<T>(
    String value,
    T? Function(Map<String, Object?> json) decodeRecord,
  ) {
    try {
      return decodeRecord(decode(value));
    } catch (_) {
      return null;
    }
  }
}
