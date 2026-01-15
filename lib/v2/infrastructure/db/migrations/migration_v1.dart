import 'package:sqflite/sqflite.dart';
import '../db_service_v2.dart';

class MigrationV1 implements DbMigration {
  @override
  int get version => 1;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // tabelas mínimas do V2 (v1 do schema do V2)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL, -- 'ganho' | 'fixa' | 'variavel'
        ativo INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS formas_pagamento (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL, -- 'dinheiro' | 'pix' | 'debito' | 'credito' | ...
        ativo INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL, -- ISO yyyy-MM-dd
        valor_centavos INTEGER NOT NULL,
        direcao TEXT NOT NULL, -- 'entrada' | 'saida' | 'transferencia'
        categoria_id INTEGER,
        forma_pagamento_id INTEGER,
        observacao TEXT,
        criado_em TEXT NOT NULL,
        atualizado_em TEXT,
        FOREIGN KEY(categoria_id) REFERENCES categorias(id),
        FOREIGN KEY(forma_pagamento_id) REFERENCES formas_pagamento(id)
      );
    ''');

    // seeds mínimos
    await db.insert('formas_pagamento', {
      'nome': 'Dinheiro',
      'tipo': 'dinheiro',
      'ativo': 1,
    });
    await db.insert('formas_pagamento', {
      'nome': 'PIX',
      'tipo': 'pix',
      'ativo': 1,
    });
  }
}
