import 'package:hive_ce/hive.dart';

import 'hive_box_registry.dart';
import 'storage_keys.dart';
import 'storage_migration.dart';

final class StorageInitializer {
  const StorageInitializer({
    this.path,
    StorageMigration migration = const StorageMigration(),
  }) : _migration = migration;

  final String? path;
  final StorageMigration _migration;

  Future<HiveBoxRegistry> initialize() async {
    final storagePath = path;
    if (storagePath != null) {
      Hive.init(storagePath);
    }

    final boxes = <String, Box<dynamic>>{};
    for (final boxName in StorageKeys.requiredBoxNames) {
      boxes[boxName] = await _openBox(boxName);
    }

    final registry = HiveBoxRegistry(Map.unmodifiable(boxes));
    await _migration.apply(registry);
    return registry;
  }

  Future<Box<dynamic>> _openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }
    return Hive.openBox<dynamic>(boxName);
  }
}
