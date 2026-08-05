import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';
import '../domain/wallet_connect_models.dart';

final walletConnectResponseOutboxProvider =
    Provider<WalletConnectResponseOutbox>(
      (ref) => InMemoryWalletConnectResponseOutbox(),
    );

final class WalletConnectErrorResponse {
  WalletConnectErrorResponse({
    required this.topic,
    required this.response,
    required this.createdAt,
  }) {
    if (response.error == null) {
      throw ArgumentError('Only WalletConnect error responses may be queued');
    }
  }

  final String topic;
  final WalletConnectResponse response;
  final DateTime createdAt;

  String get key => '$topic:${response.id}';
}

abstract interface class WalletConnectResponseOutbox {
  Future<List<WalletConnectErrorResponse>> list();

  Future<void> put(WalletConnectErrorResponse response);

  Future<void> remove({required String topic, required int id});

  Future<void> removeTopic(String topic);

  Future<void> clear();
}

final class InMemoryWalletConnectResponseOutbox
    implements WalletConnectResponseOutbox {
  static const maxEntries = 100;
  final List<WalletConnectErrorResponse> _entries = [];

  @override
  Future<List<WalletConnectErrorResponse>> list() async =>
      List.unmodifiable(_entries);

  @override
  Future<void> put(WalletConnectErrorResponse response) async {
    _entries.removeWhere((entry) => entry.key == response.key);
    _entries.add(response);
    _entries.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
  }

  @override
  Future<void> remove({required String topic, required int id}) async {
    _entries.removeWhere(
      (entry) => entry.topic == topic && entry.response.id == id,
    );
  }

  @override
  Future<void> removeTopic(String topic) async {
    _entries.removeWhere((entry) => entry.topic == topic);
  }

  @override
  Future<void> clear() async => _entries.clear();
}

final class HiveWalletConnectResponseOutbox
    implements WalletConnectResponseOutbox {
  HiveWalletConnectResponseOutbox({required HiveBoxRegistry registry})
    : _registry = registry;

  static const _version = 1;
  static const _maxEntries = 100;
  static const _maxTopicLength = 512;
  static const _maxMessageLength = 512;

  final HiveBoxRegistry _registry;
  Future<void> _tail = Future<void>.value();

  @override
  Future<List<WalletConnectErrorResponse>> list() {
    return _serialized(() async => List.unmodifiable(_read()));
  }

  @override
  Future<void> put(WalletConnectErrorResponse response) {
    return _serialized(() async {
      final entries = _read()
        ..removeWhere((entry) => entry.key == response.key)
        ..add(response)
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      if (entries.length > _maxEntries) {
        entries.removeRange(0, entries.length - _maxEntries);
      }
      await _write(entries);
    });
  }

  @override
  Future<void> remove({required String topic, required int id}) {
    return _serialized(() async {
      final entries = _read()
        ..removeWhere(
          (entry) => entry.topic == topic && entry.response.id == id,
        );
      await _write(entries);
    });
  }

  @override
  Future<void> removeTopic(String topic) {
    return _serialized(() async {
      final entries = _read()..removeWhere((entry) => entry.topic == topic);
      await _write(entries);
    });
  }

  @override
  Future<void> clear() {
    return _serialized(
      () => _registry.settingsBox.delete(
        StorageKeys.walletConnectErrorResponseOutbox,
      ),
    );
  }

  List<WalletConnectErrorResponse> _read() {
    final raw = _registry.settingsBox.get(
      StorageKeys.walletConnectErrorResponseOutbox,
    );
    if (raw is! Map || raw['version'] != _version || raw['entries'] is! List) {
      return [];
    }
    final entries = <WalletConnectErrorResponse>[];
    for (final value in raw['entries'] as List) {
      final decoded = _decode(value);
      if (decoded != null) {
        entries.add(decoded);
      }
    }
    entries.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return entries.length <= _maxEntries
        ? entries
        : entries.sublist(entries.length - _maxEntries);
  }

  Future<void> _write(List<WalletConnectErrorResponse> entries) {
    return _registry.settingsBox.put(
      StorageKeys.walletConnectErrorResponseOutbox,
      {
        'version': _version,
        'entries': [for (final entry in entries) _encode(entry)],
      },
    );
  }

  Map<String, Object?> _encode(WalletConnectErrorResponse entry) {
    final error = entry.response.error!;
    return {
      'topic': entry.topic,
      'id': entry.response.id,
      'code': error.code,
      'message': error.message,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
    };
  }

  WalletConnectErrorResponse? _decode(Object? value) {
    if (value is! Map) {
      return null;
    }
    final topic = value['topic'];
    final id = value['id'];
    final code = value['code'];
    final message = value['message'];
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    if (topic is! String ||
        topic.isEmpty ||
        topic.length > _maxTopicLength ||
        id is! int ||
        code is! int ||
        message is! String ||
        message.isEmpty ||
        message.length > _maxMessageLength ||
        createdAt == null) {
      return null;
    }
    return WalletConnectErrorResponse(
      topic: topic,
      response: WalletConnectResponse.error(
        id: id,
        error: WalletConnectResponseError(code: code, message: message),
      ),
      createdAt: createdAt.toUtc(),
    );
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
