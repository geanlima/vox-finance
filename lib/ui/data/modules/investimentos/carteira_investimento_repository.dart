import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/bluminers_config.dart';
import 'package:vox_finance/ui/data/models/investimento_carteira.dart';
import 'package:vox_finance/ui/data/models/investimento_cdi_config.dart';

class CarteiraInvestimentoRepository {
  static const _tbl = 'investimento_carteiras';

  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<InvestimentoCarteira>> listar() async {
    final db = await _db;
    final rows = await db.query(_tbl, orderBy: 'nome COLLATE NOCASE ASC');
    return rows.map((e) => InvestimentoCarteira.fromMap(e)).toList();
  }

  Future<InvestimentoCarteira?> porId(int id) async {
    final db = await _db;
    final rows = await db.query(_tbl, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InvestimentoCarteira.fromMap(rows.first);
  }

  /// Cria carteira + linha de config Bluminers vazia para o layout bluminers.
  Future<int> salvar(InvestimentoCarteira c) async {
    final db = await _db;
    if (c.id == null) {
      final dados = c.toMap()..remove('id');
      final id = await db.insert(_tbl, dados);
      if (c.layout == 'bluminers') {
        await db.insert(
          'investimento_bluminers_config',
          BluminersConfig(
            idCarteira: id,
            saldoInicialInvestido: 0,
            saldoInicialDisponivel: 0,
            aporteMensal: 0,
            meta: null,
            criadoEm: DateTime.now(),
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (c.layout == 'cdi_faixas') {
        await db.insert(
          'investimento_cdi_config',
          InvestimentoCdiConfig(
            idCarteira: id,
            limiteFaixa: 10000,
            cdiBaseAnual: 0,
            pctAteLimite: 100,
            pctAcimaLimite: 100,
            idContaBancaria: null,
            saldoBase: 0,
            usarTaxaFixa: false,
            taxaDiariaFixa: 0.000433,
            aporteFixo: 2000,
            considerarFimSemana: false,
            considerarFeriados: false,
            criadoEm: DateTime.now(),
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return id;
    }
    final dados = c.toMap()..remove('id');
    return db.update(_tbl, dados, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.transaction((txn) async {
      // -------------------------
      // CDI (faixas): remove histórico + lançamentos vinculados
      // -------------------------
      try {
        final rows = await txn.query(
          'investimento_cdi_rendimentos',
          columns: const ['id_lancamento'],
          where: 'id_carteira = ? AND id_lancamento IS NOT NULL',
          whereArgs: [id],
        );
        final idsLanc = <int>[];
        for (final r in rows) {
          final v = r['id_lancamento'];
          if (v is int) idsLanc.add(v);
          if (v is num) idsLanc.add(v.toInt());
        }

        if (idsLanc.isNotEmpty) {
          final placeholders = List.filled(idsLanc.length, '?').join(',');
          // apaga conta_pagar vinculada primeiro (se existir)
          await txn.delete(
            'conta_pagar',
            where: 'id_lancamento IN ($placeholders)',
            whereArgs: idsLanc,
          );
          // apaga lançamentos de rendimento
          await txn.delete(
            'lancamentos',
            where: 'id IN ($placeholders)',
            whereArgs: idsLanc,
          );
        }

        await txn.delete(
          'investimento_cdi_rendimentos',
          where: 'id_carteira = ?',
          whereArgs: [id],
        );
      } catch (_) {
        // se tabelas não existirem na base do usuário, segue o fluxo
      }

      await txn.delete(
        'investimento_bluminers_movimentos',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'investimento_bluminers_rentabilidade',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'investimento_bluminers_config',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'investimento_cdi_config',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(_tbl, where: 'id = ?', whereArgs: [id]);

      // Se o usuário apagar todas as carteiras, recria uma principal vazia
      // para o app não ficar sem carteira padrão.
      final cnt = await txn.rawQuery('SELECT COUNT(*) AS c FROM $_tbl;');
      final n = (cnt.first['c'] as int?) ?? 0;
      if (n == 0) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await txn.insert(
          _tbl,
          {
            'id': 1,
            'nome': 'Carteira principal',
            'layout': 'bluminers',
            'criado_em': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'investimento_bluminers_config',
          BluminersConfig(
            idCarteira: 1,
            saldoInicialInvestido: 0,
            saldoInicialDisponivel: 0,
            aporteMensal: 0,
            meta: null,
            criadoEm: DateTime.now(),
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
