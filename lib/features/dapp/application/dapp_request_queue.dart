import 'dart:async';

final class DappRequestQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) => _run(operation, completer));
    return completer.future;
  }

  Future<void> _run<T>(
    Future<T> Function() operation,
    Completer<T> completer,
  ) async {
    try {
      completer.complete(await operation());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }
}
