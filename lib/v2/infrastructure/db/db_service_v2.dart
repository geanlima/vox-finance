// ignore_for_file: avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v10_parcelamentos.dart';
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v11_formas_pagamento_upgrade.dart';
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v12_dividas.dart';
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v13_pessoas_devedoras.dart';
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v14_cofrinho.dart';
import 'package:vox_finance/v2/infrastructure/db/migrations/migration_v15_desejos_compras.dart';

import 'migrations/migration_v1.dart';
import 'migrations/migration_v2.dart';
import 'migrations/migration_v3_notas_rapidas.dart';
import 'migrations/migration_v4_vencimentos.dart';
import 'migrations/migration_v5_balanco_indexes.dart';
import 'migrations/migration_v6_categorias_limites.dart';
import 'migrations/migration_v7_ganhos.dart';
import 'migrations/migration_v8_despesas_fixas.dart';
import 'migrations/migration_v9_despesas_variaveis.dart';

class DbServiceV2 {
  static const _dbName = 'vox_finance_v2.db';
  static const _latest = 15;

  Database? _db;
  Database get db => _db!;

  Future<void> openAndMigrate() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, _dbName);

    // ✅ Se quiser resetar (debug) uma vez:
    // await deleteDatabase(dbPath);

    _db = await openDatabase(
      dbPath,
      version: _latest,
      onCreate: (db, version) async {
        await db.execute('PRAGMA user_version = 0;');
        await _runMigrations(db, fromVersion: 0);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _runMigrations(db, fromVersion: oldVersion);
      },
    );

    final uv =
        Sqflite.firstIntValue(await _db!.rawQuery('PRAGMA user_version;')) ??
        -1;
    final tables = await _db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
    );
    print('✅ user_version=$uv');
    print('✅ tables=$tables');
  }

  Future<bool> _columnExists(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final r = await db.rawQuery("PRAGMA table_info($table);");
    return r.any((e) => e['name'] == column);
  }

  Future<void> _repairColumnsIfMissing(Database db) async {
    // se já está em versão alta mas faltam colunas, cria na marra
    final hasPrincipal = await _columnExists(
      db,
      'formas_pagamento',
      'principal',
    );
    if (hasPrincipal) return;

    await db.transaction((txn) async {
      final m = MigrationV11FormasPagamentoUpgrade();
      await m.up(txn);
    });
  }

  Future<void> _runMigrations(Database db, {required int fromVersion}) async {
    final migrations = <DbMigration>[
      MigrationV1(),
      MigrationV2(),
      MigrationV3NotasRapidas(),
      MigrationV4Vencimentos(),
      MigrationV5BalancoIndexes(),
      MigrationV6CategoriasLimites(),
      MigrationV7Ganhos(),
      MigrationV8DespesasFixas(),
      MigrationV9DespesasVariaveis(),
      MigrationV10Parcelamentos(),
      MigrationV11FormasPagamentoUpgrade(),
      MigrationV12Dividas(),
      MigrationV13PessoasDevedoras(),
      MigrationV14Cofrinho(),
      MigrationV15DesejosCompras(),
    ]..sort((a, b) => a.version.compareTo(b.version));

    final current =
        Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version;')) ?? 0;

    await _repairColumnsIfMissing(db);
    // =====================
    // 🔧 REPAIR AUTOMÁTICO
    // =====================
    await _repairIfMissing(db, current, 7, 'ganhos', MigrationV7Ganhos().up);
    await _repairIfMissing(
      db,
      current,
      8,
      'despesas_fixas',
      MigrationV8DespesasFixas().up,
    );
    await _repairIfMissing(
      db,
      current,
      9,
      'despesas_variaveis',
      MigrationV9DespesasVariaveis().up,
    );

    // ✅ roda apenas migrations necessárias
    for (final m in migrations) {
      if (m.version <= fromVersion) continue;
      if (m.version <= current) continue;

      await db.transaction((txn) async {
        await m.up(txn);
        await txn.execute('PRAGMA user_version = ${m.version};');
      });
    }
  }

  Future<void> _repairIfMissing(
    Database db,
    int current,
    int version,
    String table,
    Future<void> Function(DatabaseExecutor) up,
  ) async {
    if (current < version) return;

    final exists = await _tableExists(db, table);
    if (exists) return;

    print('⚠️ REPAIR: criando tabela ausente $table (v$version+)');
    await db.transaction((txn) async {
      await up(txn);
    });
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final r = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return r.isNotEmpty;
  }
}

abstract class DbMigration {
  int get version;
  Future<void> up(DatabaseExecutor db);
}
