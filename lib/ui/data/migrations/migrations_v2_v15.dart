// core/database/migrations/migrations_v2_v15.dart
import 'package:sqflite/sqflite.dart';

class MigrationV2toV15 {
  /// Executa todas as migrações da 2 até a 15,
  /// dependendo do [oldVersion].
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // ---- V4: id_cartao em lancamentos + tabela cartao_credito básica ----
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE lancamentos ADD COLUMN id_cartao INTEGER;',
        );
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cartao_credito (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descricao TEXT NOT NULL,
          bandeira TEXT NOT NULL,
          ultimos4 TEXT NOT NULL
        );
      ''');
    }

    // ---- V6: foto_path + dia_vencimento no cartão ----
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN foto_path TEXT;',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN dia_vencimento INTEGER;',
        );
      } catch (_) {}
    }

    // ---- V7: tabela USUARIOS ----
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usuarios (
          id INTEGER PRIMARY KEY,
          email TEXT NOT NULL,
          nome TEXT,
          senha TEXT NOT NULL,
          foto_path TEXT,
          criado_em TEXT NOT NULL
        );
      ''');
    }

    // ---- V8: adiciona foto_path em bancos antigos (se faltar) ----
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
      } catch (_) {}
    }

    // ---- V9: tipo, permite_parcelamento, limite, dia_fechamento ----
    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN tipo INTEGER DEFAULT 0;',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN permite_parcelamento INTEGER DEFAULT 1;',
        );
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE cartao_credito ADD COLUMN limite REAL;');
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN dia_fechamento INTEGER;',
        );
      } catch (_) {}
    }

    // ---- V10: controla_fatura ----
    if (oldVersion < 10) {
      try {
        await db.execute(
          'ALTER TABLE cartao_credito ADD COLUMN controla_fatura INTEGER DEFAULT 1;',
        );
      } catch (_) {}

      try {
        await db.execute('''
          UPDATE cartao_credito
          SET controla_fatura = permite_parcelamento
          WHERE controla_fatura IS NULL
             OR (controla_fatura = 0 AND permite_parcelamento = 1);
        ''');
      } catch (_) {}
    }

    // ---- V11: conta_bancaria + id_conta em lancamentos ----
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conta_bancaria (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          descricao TEXT NOT NULL,
          banco TEXT,
          agencia TEXT,
          numero TEXT,
          tipo TEXT,
          ativa INTEGER NOT NULL DEFAULT 1
        );
      ''');

      try {
        await db.execute(
          'ALTER TABLE lancamentos ADD COLUMN id_conta INTEGER;',
        );
      } catch (_) {}
    }

    // ---- V13: normaliza nome da coluna 'ultimos4' ----
    if (oldVersion < 13) {
      try {
        final info = await db.rawQuery('PRAGMA table_info(cartao_credito);');

        final temUltimos4 = info.any(
          (col) => (col['name'] as String).toLowerCase() == 'ultimos4',
        );

        const possiveisAntigos = [
          'ultimo_4_digitos',
          'ultimo_4_digito',
          'ultimos_4_digito',
          'ultimos_4_digitos',
          'ultimos4_digitos',
          'ultimos_4',
          'ultimos_digitos',
        ];

        String? colunaAntiga;
        for (final col in info) {
          final nome = (col['name'] as String).toLowerCase();
          if (possiveisAntigos.contains(nome)) {
            colunaAntiga = col['name'] as String;
            break;
          }
        }

        if (!temUltimos4 && colunaAntiga != null) {
          await db.execute(
            'ALTER TABLE cartao_credito '
            'RENAME COLUMN $colunaAntiga TO ultimos4;',
          );
        }
      } catch (_) {}
    }

    // ---- V14 / V15: garante id_conta em lancamentos ----
    if (oldVersion < 15) {
      try {
        final infoLanc = await db.rawQuery('PRAGMA table_info(lancamentos);');

        final temIdConta = infoLanc.any(
          (col) => (col['name'] as String).toLowerCase() == 'id_conta',
        );

        if (!temIdConta) {
          await db.execute(
            'ALTER TABLE lancamentos ADD COLUMN id_conta INTEGER;',
          );
        }
      } catch (_) {}
    }

    // ---- V16: adiciona id_lancamento em conta_pagar ----
    if (oldVersion < 16) {
      try {
        await db.execute(
          'ALTER TABLE conta_pagar ADD COLUMN id_lancamento INTEGER;',
        );
      } catch (_) {}
    }
  }

  /// Ajustes que você fazia no `onOpen` (garantir tabelas/colunas).
  static Future<void> ensureTables(Database db) async {
    // USUÁRIOS
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        nome TEXT,
        senha TEXT NOT NULL,
        foto_path TEXT,
        criado_em TEXT NOT NULL
      );
    ''');

    try {
      await db.execute('ALTER TABLE usuarios ADD COLUMN senha TEXT;');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE usuarios ADD COLUMN foto_path TEXT;');
    } catch (_) {}

    // CONTA_BANCARIA
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conta_bancaria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT NOT NULL,
        banco TEXT,
        agencia TEXT,
        numero TEXT,
        tipo TEXT,
        ativa INTEGER NOT NULL DEFAULT 1
      );
    ''');
  }
}
