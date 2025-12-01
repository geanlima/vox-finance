// lib/ui/data/database/database_initializer.dart
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_config.dart';
import 'package:vox_finance/ui/data/migrations/migration_factory.dart';

class DatabaseInitializer {
  static Future<Database> initialize() async {
    final path = await DatabaseConfig.getDatabasePath();

    return await openDatabase(
      path,
      version: DatabaseConfig.dbVersion,
      onCreate: (db, version) async {
        // agora o create sabe qual é a versão alvo (17)
        await MigrationFactory.create(db, version);
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
