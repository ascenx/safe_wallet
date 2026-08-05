import 'dart:typed_data';

final class SensitiveBytes {
  SensitiveBytes(List<int> bytes) : _bytes = Uint8List.fromList(bytes);

  Uint8List? _bytes;

  bool get isDestroyed => _bytes == null;

  List<int> copyBytes() {
    final current = _bytes;
    if (current == null) {
      throw StateError('Sensitive bytes have been destroyed');
    }
    return Uint8List.fromList(current);
  }

  void destroy() {
    final current = _bytes;
    if (current == null) {
      return;
    }
    for (var index = 0; index < current.length; index += 1) {
      current[index] = 0;
    }
    _bytes = null;
  }
}
