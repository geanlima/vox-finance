// lib/ui/data/migrations/migration_factory.dart

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/migrations/migrations_v1.dart';

// os nomes abaixo DEVEM bater com os arquivos de verdade
import 'migrations_v2_v15.dart';

class MigrationFactory {
  /// Criação inicial (versão 1) – cria todas as tabelas base
  /// e já aplica migrações até a versão alvo.
  static Future<void> create(Database db, int targetVersion) async {
    // cria estrutura base (v1)
    await MigrationV1.create(db);

    // aplica todas as migrações de 2 até targetVersion (hoje 22)
    await MigrationV2toV15.upgrade(db, 1, targetVersion);
  }

  /// Upgrades do banco – da versão [oldVersion] até [newVersion]
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
