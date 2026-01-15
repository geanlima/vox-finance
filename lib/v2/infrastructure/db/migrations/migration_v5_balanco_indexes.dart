import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV5BalancoIndexes implements DbMigration {
  @override
  int get version => 5;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // ✅ índices para consultas por mês/ano (muito usados no balanço)
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mov_data ON movimentos(data);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mov_direcao ON movimentos(direcao);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mov_categoria ON movimentos(categoria_id);',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cat_tipo ON categorias(tipo);',
    );

    // ✅ garante que categorias.tipo exista (se seu schema antigo não tiver)
    // (sqflite não tem IF NOT EXISTS para coluna, então checamos com PRAGMA)
    final cols = await db.rawQuery("PRAGMA table_info(categorias)");
    final hasTipo = cols.any((c) => c['name'] == 'tipo');
    if (!hasTipo) {
      await db.execute(
        "ALTER TABLE categorias ADD COLUMN tipo TEXT NOT NULL DEFAULT 'variavel';",
      );
    }

    // ✅ garante que movimentos.direcao exista (mesmo motivo)
    final colsMov = await db.rawQuery("PRAGMA table_info(movimentos)");
    final hasDirecao = colsMov.any((c) => c['name'] == 'direcao');
    if (!hasDirecao) {
      await db.execute(
        "ALTER TABLE movimentos ADD COLUMN direcao TEXT NOT NULL DEFAULT 'saida';",
      );
    }

    // ✅ opcional: se quiser cache futuro (deixe comentado por enquanto)
    // await db.execute('''
    //   CREATE TABLE IF NOT EXISTS balanco_mensal_cache (
    //     ano INTEGER NOT NULL,
    //     mes INTEGER NOT NULL,
    //     ganhos INTEGER NOT NULL DEFAULT 0,
    //     gastos_fixos INTEGER NOT NULL DEFAULT 0,
    //     gastos_variaveis INTEGER NOT NULL DEFAULT 0,
    //     parcelas INTEGER NOT NULL DEFAULT 0,
    //     dividas INTEGER NOT NULL DEFAULT 0,
    //     atualizado_em TEXT NOT NULL,
    //     PRIMARY KEY (ano, mes)
    //   );
    // ''');
  }
}
