// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV6CategoriasLimites implements DbMigration {
  @override
  int get version => 6;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // ✅ 1) Garantir tabela categorias existe (compatível com V1)
    // Se a V1 já criou, isso não muda nada; mas garante em banco novo.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // ✅ 2) Adicionar colunas novas (emoji/cor) se não existirem
    await _addColumnIfMissing(db, 'categorias', 'emoji', 'TEXT');
    await _addColumnIfMissing(db, 'categorias', 'cor_hex', 'TEXT');

    // ✅ 3) Criar limites por mês/ano
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categoria_limites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER NOT NULL,
        ano INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        limite_centavos INTEGER NOT NULL DEFAULT 0,
        criado_em TEXT NOT NULL,
        atualizado_em TEXT,
        UNIQUE(categoria_id, ano, mes),
        FOREIGN KEY(categoria_id) REFERENCES categorias(id)
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cat_limites_cat_ano_mes
      ON categoria_limites(categoria_id, ano, mes);
    ''');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String type,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info(' + table + ');');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute(
        'ALTER TABLE ' + table + ' ADD COLUMN ' + column + ' ' + type + ';',
      );
    }
  }
}
