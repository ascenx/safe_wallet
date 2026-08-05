import 'dart:async';
import 'dart:collection';

import '../domain/wallet_connect_models.dart';

enum WalletConnectEnqueueResult { accepted, duplicate, expired, full }

final class WalletConnectRequestQueue {
  WalletConnectRequestQueue({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  static const maxPendingRequests = 100;
  static const maxCompletedDedupeKeys = 1024;
  final Queue<WalletConnectRequest> _pending = Queue();
  final Set<String> _pendingKeys = {};
  final LinkedHashSet<String> _completedKeys = LinkedHashSet();
  final StreamController<WalletConnectRequest> _controller =
      StreamController.broadcast(sync: true);
  final StreamController<WalletConnectRequest> _cancellationController =
      StreamController.broadcast(sync: true);

  WalletConnectRequest? _active;
  bool _disposed = false;

  Stream<WalletConnectRequest> get requests => _controller.stream;
  Stream<WalletConnectRequest> get cancelledRequests =>
      _cancellationController.stream;
  WalletConnectRequest? get activeRequest => _active;
  int get pendingCount => _pending.length;
  int get completedDedupeCount => _completedKeys.length;

  WalletConnectEnqueueResult enqueue(WalletConnectRequest request) {
    if (_pendingKeys.contains(request.dedupeKey) ||
        _completedKeys.contains(request.dedupeKey)) {
      return WalletConnectEnqueueResult.duplicate;
    }
    if (request.isExpiredAt(_now())) {
      return WalletConnectEnqueueResult.expired;
    }
    if (_pending.length + (_active == null ? 0 : 1) >= maxPendingRequests) {
      return WalletConnectEnqueueResult.full;
    }
    _pendingKeys.add(request.dedupeKey);
    _pending.add(request);
    _drain();
    return WalletConnectEnqueueResult.accepted;
  }

  void replayActive() {
    final active = _active;
    if (!_disposed && active != null) {
      _controller.add(active);
    }
  }

  bool complete({required String topic, required int id}) {
    final active = _active;
    if (active == null || active.topic != topic || active.id != id) {
      return false;
    }
    _active = null;
    _pendingKeys.remove(active.dedupeKey);
    _rememberCompleted(active.dedupeKey);
    _drain();
    return true;
  }

  int cancelTopic(String topic) {
    var cancelled = 0;
    if (_active?.topic == topic) {
      _cancellationController.add(_active!);
      _pendingKeys.remove(_active!.dedupeKey);
      _rememberCompleted(_active!.dedupeKey);
      _active = null;
      cancelled += 1;
    }
    final retained = _pending
        .where((request) {
          if (request.topic == topic) {
            _cancellationController.add(request);
            _pendingKeys.remove(request.dedupeKey);
            _rememberCompleted(request.dedupeKey);
            cancelled += 1;
            return false;
          }
          return true;
        })
        .toList(growable: false);
    _pending
      ..clear()
      ..addAll(retained);
    _drain();
    return cancelled;
  }

  int cancelAll() {
    var cancelled = 0;
    final active = _active;
    if (active != null) {
      _cancellationController.add(active);
      _rememberCompleted(active.dedupeKey);
      _active = null;
      cancelled += 1;
    }
    for (final request in _pending) {
      _cancellationController.add(request);
      _rememberCompleted(request.dedupeKey);
      cancelled += 1;
    }
    _pending.clear();
    _pendingKeys.clear();
    return cancelled;
  }

  void _drain() {
    if (_disposed || _active != null) {
      return;
    }
    while (_pending.isNotEmpty) {
      final next = _pending.removeFirst();
      if (next.isExpiredAt(_now())) {
        _pendingKeys.remove(next.dedupeKey);
        _rememberCompleted(next.dedupeKey);
        continue;
      }
      _active = next;
      _controller.add(next);
      return;
    }
  }

  void _rememberCompleted(String key) {
    _completedKeys.add(key);
    while (_completedKeys.length > maxCompletedDedupeKeys) {
      _completedKeys.remove(_completedKeys.first);
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pending.clear();
    _pendingKeys.clear();
    _completedKeys.clear();
    _active = null;
    await _controller.close();
    await _cancellationController.close();
  }
}
