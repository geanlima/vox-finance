// lib/ui/data/migrations/migration_factory.dart

import 'package:sqflite/sqflite.dart';

import 'migrations_v1.dart';
import 'migrations_v2_v15.dart';

class MigrationFactory {
  /// Criação inicial (versão 1) – cria todas as tabelas do zero
  static Future<void> create(Database db) async {
    await MigrationV1.create(db);
  }

  /// Upgrades do banco (2 até 15) – usando o oldVersion
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await MigrationV2toV15.upgrade(db, oldVersion, newVersion);
  }

  /// Ajustes pós-abertura (garante tabelas/colunas core)
  static Future<void> ensureIntegrity(Database db) async {
    await MigrationV2toV15.ensureTables(db);
  }
}
