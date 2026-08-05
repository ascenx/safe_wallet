import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/shared/storage/hive_box_registry.dart';
import 'package:safe_wallet/shared/storage/json_codec.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/storage_keys.dart';
import 'package:safe_wallet/shared/storage/storage_migration.dart';

void main() {
  group('StorageInitializer', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_storage_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('opens all required boxes and stores schema version', () async {
      final initializer = StorageInitializer(path: tempDirectory.path);

      final registry = await initializer.initialize();

      expect(registry, isA<HiveBoxRegistry>());
      for (final boxName in StorageKeys.requiredBoxNames) {
        expect(registry.isOpen(boxName), isTrue, reason: '$boxName is open');
      }
      expect(
        StorageKeys.requiredBoxNames,
        contains(StorageKeys.tokenPricesBox),
      );
      expect(
        StorageKeys.requiredBoxNames,
        contains(StorageKeys.tokenBalancesBox),
      );
      expect(
        registry.settingsBox.get(StorageKeys.schemaVersion),
        StorageMigration.currentSchemaVersion,
      );
    });

    test('can run twice without data loss', () async {
      final initializer = StorageInitializer(path: tempDirectory.path);
      final firstRegistry = await initializer.initialize();

      await firstRegistry.settingsBox.put('sentinel', 'keep-me');

      final secondRegistry = await initializer.initialize();

      expect(secondRegistry.settingsBox.get('sentinel'), 'keep-me');
      expect(
        secondRegistry.settingsBox.get(StorageKeys.schemaVersion),
        StorageMigration.currentSchemaVersion,
      );
    });

    test('runs the v1 to v2 migration before advancing the schema', () async {
      final firstRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      await firstRegistry.settingsBox.put(StorageKeys.schemaVersion, 1);
      await firstRegistry.settingsBox.put('legacy', 'value');
      var observedVersion = -1;

      final registry = await StorageInitializer(
        path: tempDirectory.path,
        migration: StorageMigration(
          migrateV1ToV2: (registry) async {
            observedVersion =
                registry.settingsBox.get(StorageKeys.schemaVersion) as int;
            await registry.settingsBox.put('migrated', true);
          },
        ),
      ).initialize();

      expect(observedVersion, 1);
      expect(registry.settingsBox.get('migrated'), isTrue);
      expect(
        registry.settingsBox.get(StorageKeys.schemaVersion),
        StorageMigration.currentSchemaVersion,
      );
    });

    test('does not advance the schema when a migration step fails', () async {
      final firstRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      await firstRegistry.settingsBox.put(StorageKeys.schemaVersion, 1);

      await expectLater(
        StorageInitializer(
          path: tempDirectory.path,
          migration: StorageMigration(
            migrateV1ToV2: (_) async => throw StateError('migration failed'),
          ),
        ).initialize(),
        throwsStateError,
      );

      expect(firstRegistry.settingsBox.get(StorageKeys.schemaVersion), 1);
    });

    test('rejects a storage schema created by a newer app version', () async {
      final firstRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      await firstRegistry.settingsBox.put(
        StorageKeys.schemaVersion,
        StorageMigration.currentSchemaVersion + 1,
      );

      await expectLater(
        StorageInitializer(path: tempDirectory.path).initialize(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('encodes and decodes json maps for storage adapters', () {
      const codec = StorageJsonCodec();
      final encoded = codec.encode({'chainId': '1', 'enabled': true});

      expect(encoded, isA<String>());
      expect(codec.decode(encoded), {'chainId': '1', 'enabled': true});
    });

    test('isolates a malformed record while decoding a Hive collection', () {
      const codec = StorageJsonCodec();

      expect(
        codec.tryDecode('not-json', (json) => json['id'] as String),
        isNull,
      );
      expect(
        codec.tryDecode(
          codec.encode({'id': 7}),
          (json) => json['id'] as String,
        ),
        isNull,
      );
      expect(
        codec.tryDecode(
          codec.encode({'id': 'valid'}),
          (json) => json['id'] as String,
        ),
        'valid',
      );
    });
  });
}
