import 'hive_box_registry.dart';
import 'storage_keys.dart';

typedef StorageMigrationStep = Future<void> Function(HiveBoxRegistry registry);

final class StorageMigration {
  const StorageMigration({this.migrateV1ToV2});

  static const currentSchemaVersion = 2;

  final StorageMigrationStep? migrateV1ToV2;

  Future<void> apply(HiveBoxRegistry registry) async {
    final settingsBox = registry.settingsBox;
    final storedVersion = settingsBox.get(StorageKeys.schemaVersion);
    if (storedVersion != null && (storedVersion is! int || storedVersion < 0)) {
      throw const FormatException('Stored schema version is invalid');
    }
    var version = storedVersion as int? ?? 0;
    if (version > currentSchemaVersion) {
      throw UnsupportedError(
        'Storage schema $version is newer than supported schema '
        '$currentSchemaVersion',
      );
    }
    if (version == currentSchemaVersion) {
      return;
    }

    if (version == 0) {
      await settingsBox.put(StorageKeys.schemaVersion, 1);
      version = 1;
    }

    if (version == 1) {
      final migration = migrateV1ToV2;
      if (migration != null) {
        await migration(registry);
      } else if (storedVersion != null || _hasLegacyData(registry)) {
        throw StateError('The v1 to v2 storage migration is not configured');
      }
      await settingsBox.put(StorageKeys.schemaVersion, 2);
    }
  }

  bool _hasLegacyData(HiveBoxRegistry registry) {
    for (final boxName in StorageKeys.requiredBoxNames) {
      final box = registry.box(boxName);
      if (boxName == StorageKeys.settingsBox) {
        if (box.keys.any((key) => key != StorageKeys.schemaVersion)) {
          return true;
        }
      } else if (box.isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
