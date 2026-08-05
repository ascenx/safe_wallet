import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_response_outbox.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/storage_keys.dart';

void main() {
  group('HiveWalletConnectResponseOutbox', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_wallet_connect_outbox_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'persists only the JSON-RPC error fields across storage reopen',
      () async {
        final registry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        final outbox = HiveWalletConnectResponseOutbox(registry: registry);
        await outbox.put(_errorResponse(topic: 'topic-a', id: 7));

        final stored =
            registry.settingsBox.get(
                  StorageKeys.walletConnectErrorResponseOutbox,
                )
                as Map;
        final storedEntry = (stored['entries'] as List).single as Map;
        expect(storedEntry.keys, {
          'topic',
          'id',
          'code',
          'message',
          'createdAt',
        });

        await Hive.close();
        final reopenedRegistry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        final reopenedOutbox = HiveWalletConnectResponseOutbox(
          registry: reopenedRegistry,
        );

        final entries = await reopenedOutbox.list();
        expect(entries, hasLength(1));
        expect(entries.single.topic, 'topic-a');
        expect(entries.single.response.id, 7);
        expect(entries.single.response.result, isNull);
        expect(entries.single.response.error?.code, -32000);
        expect(entries.single.response.error?.message, 'Request failed');
        expect(entries.single.createdAt, DateTime.utc(2026, 8, 2, 1));
      },
    );

    test(
      'ignores malformed persisted entries without hiding valid entries',
      () async {
        final registry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        await registry.settingsBox.put(
          StorageKeys.walletConnectErrorResponseOutbox,
          {
            'version': 1,
            'entries': [
              {
                'topic': 'topic-a',
                'id': 7,
                'code': -32000,
                'message': 'Request failed',
                'createdAt': '2026-08-02T01:00:00.000Z',
              },
              {'topic': 'topic-b', 'id': 'not-an-int'},
              'not-an-entry',
            ],
          },
        );

        final entries = await HiveWalletConnectResponseOutbox(
          registry: registry,
        ).list();

        expect(entries, hasLength(1));
        expect(entries.single.topic, 'topic-a');
      },
    );

    test('rejects successful responses before they can be persisted', () {
      expect(
        () => WalletConnectErrorResponse(
          topic: 'topic-a',
          response: const WalletConnectResponse.success(
            id: 7,
            result: 'signed-payload',
          ),
          createdAt: DateTime.utc(2026, 8, 2),
        ),
        throwsArgumentError,
      );
    });
  });
}

WalletConnectErrorResponse _errorResponse({
  required String topic,
  required int id,
}) {
  return WalletConnectErrorResponse(
    topic: topic,
    response: WalletConnectResponse.error(
      id: id,
      error: const WalletConnectResponseError(
        code: -32000,
        message: 'Request failed',
      ),
    ),
    createdAt: DateTime.utc(2026, 8, 2, 1),
  );
}
