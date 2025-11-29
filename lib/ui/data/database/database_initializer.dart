// lib/ui/data/database/database_initializer.dart
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_config.dart';
import 'package:vox_finance/ui/data/migrations/migration_factory.dart';

class DatabaseInitializer {
  static Future<Database> initialize() async {
    final path = await DatabaseConfig.getDatabasePath();

    return await openDatabase(
      path,
      version: DatabaseConfig.dbVersion, // 15
      onCreate: (db, version) async {
        await MigrationFactory.create(db); // 👈 só db
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await MigrationFactory.upgrade(db, oldVersion, newVersion);
      },
      onOpen: (db) async {
        await MigrationFactory.ensureIntegrity(db);
      },
    );
  }
}
