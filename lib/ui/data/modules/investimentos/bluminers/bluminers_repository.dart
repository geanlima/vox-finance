import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/bluminers_config.dart';
import 'package:vox_finance/ui/data/models/bluminers_movimento.dart';
import 'package:vox_finance/ui/data/models/bluminers_rentabilidade.dart';

class BluminersRepository {
  static const _tblConfig = 'investimento_bluminers_config';
  static const _tblMov = 'investimento_bluminers_movimentos';
  static const _tblRent = 'investimento_bluminers_rentabilidade';

  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<BluminersConfig> getConfig() async {
    final db = await _db;
    final rows = await db.query(_tblConfig, where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) {
      final cfg = BluminersConfig(
        saldoInicialInvestido: 0,
        saldoInicialDisponivel: 0,
        aporteMensal: 0,
        meta: null,
        criadoEm: DateTime.now(),
      );
      await db.insert(_tblConfig, cfg.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return cfg;
    }
    return BluminersConfig.fromMap(rows.first);
  }

  Future<void> saveConfig(BluminersConfig cfg) async {
    final db = await _db;
    await db.insert(_tblConfig, cfg.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BluminersMovimento>> listarMovimentos() async {
    final db = await _db;
    final rows = await db.query(_tblMov, orderBy: 'data DESC, id DESC');
    return rows.map((e) => BluminersMovimento.fromMap(e)).toList();
  }

  Future<int> salvarMovimento(BluminersMovimento mov) async {
    final db = await _db;
    if (mov.id == null) {
      final dados = mov.toMap()..remove('id');
      return db.insert(_tblMov, dados);
    }
    return db.update(_tblMov, mov.toMap(), where: 'id = ?', whereArgs: [mov.id]);
  }

  Future<void> deletarMovimento(int id) async {
    final db = await _db;
    await db.delete(_tblMov, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BluminersRentabilidade>> listarRentabilidade() async {
    final db = await _db;
    final rows = await db.query(_tblRent, orderBy: 'data DESC, id DESC');
    return rows.map((e) => BluminersRentabilidade.fromMap(e)).toList();
  }

  Future<void> deletarRentabilidade(BluminersRentabilidade item) async {
    final db = await _db;
    if (item.id != null) {
      await db.delete(_tblRent, where: 'id = ?', whereArgs: [item.id]);
    } else {
      await db.delete(
        _tblRent,
        where: 'data = ?',
        whereArgs: [DateTime(item.data.year, item.data.month, item.data.day).millisecondsSinceEpoch],
      );
    }

    // remove movimento auto correspondente
    await db.delete(
      _tblMov,
      where: 'origem = ? AND id_origem = ?',
      whereArgs: ['rentabilidade', item.id],
    );
  }

  Future<double> saldoAte(DateTime data, {bool inclusive = true}) async {
    final s = await saldosAte(data, inclusive: inclusive);
    return s.totalGeral;
  }

  Future<({double investido, double disponivel, double totalGeral})> saldosAte(
    DateTime data, {
    bool inclusive = true,
  }) async {
    final cfg = await getConfig();
    final db = await _db;
    final ts = DateTime(data.year, data.month, data.day).millisecondsSinceEpoch;
    final op = inclusive ? '<=' : '<';

    final rows = await db.rawQuery('''
      SELECT
        carteira,
        COALESCE(SUM(CASE WHEN tipo = ? THEN valor ELSE 0 END), 0) AS aportes,
        COALESCE(SUM(CASE WHEN tipo = ? THEN valor ELSE 0 END), 0) AS saques,
        COALESCE(SUM(CASE WHEN tipo = ? THEN valor ELSE 0 END), 0) AS rendimentos,
        COALESCE(SUM(CASE WHEN tipo = ? THEN valor ELSE 0 END), 0) AS ajustes
      FROM $_tblMov
      WHERE data $op ?
      GROUP BY carteira
    ''', [
      BluminersMovimentoTipo.aporte.index,
      BluminersMovimentoTipo.saque.index,
      BluminersMovimentoTipo.rendimento.index,
      BluminersMovimentoTipo.ajuste.index,
      ts,
    ]);

    double inv = cfg.saldoInicialInvestido;
    double disp = cfg.saldoInicialDisponivel;

    for (final r in rows) {
      final carteira = (r['carteira'] as int?) ?? 0;
      final aportes = (r['aportes'] as num).toDouble();
      final saques = (r['saques'] as num).toDouble();
      final rend = (r['rendimentos'] as num).toDouble();
      final ajustes = (r['ajustes'] as num).toDouble();

      if (carteira == BluminersCarteira.investido.index) {
        inv += aportes + ajustes;
      } else {
        disp += rend + ajustes - saques;
      }
    }

    return (investido: inv, disponivel: disp, totalGeral: inv + disp);
  }

  Future<BluminersRentabilidade> salvarRentabilidade({
    int? id,
    required DateTime data,
    required double percentual,
  }) async {
    final db = await _db;
    final dia = DateTime(data.year, data.month, data.day);

    // Base do rendimento do dia:
    // - inclui aportes/resgates/ajustes lançados NO DIA
    // - não inclui o rendimento do próprio dia (que será criado aqui)
    final tsDia = dia.millisecondsSinceEpoch;
    final rowsDia = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS aportes_inv,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS ajustes_inv,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS saques_disp,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS ajustes_disp
      FROM $_tblMov
      WHERE data = ?
    ''', [
      BluminersMovimentoTipo.aporte.index,
      BluminersCarteira.investido.index,
      BluminersMovimentoTipo.ajuste.index,
      BluminersCarteira.investido.index,
      BluminersMovimentoTipo.saque.index,
      BluminersCarteira.disponivel.index,
      BluminersMovimentoTipo.ajuste.index,
      BluminersCarteira.disponivel.index,
      tsDia,
    ]);

    final d = rowsDia.first;
    final aportesInvDia = (d['aportes_inv'] as num).toDouble();
    final ajustesInvDia = (d['ajustes_inv'] as num).toDouble();
    final saquesDispDia = (d['saques_disp'] as num).toDouble();
    final ajustesDispDia = (d['ajustes_disp'] as num).toDouble();

    final saldoAteOntem = await saldosAte(dia, inclusive: false);
    final baseRendimento =
        saldoAteOntem.totalGeral + aportesInvDia + ajustesInvDia + ajustesDispDia - saquesDispDia;
    final rendimentoValor = baseRendimento * (percentual / 100.0);

    // upsert rentabilidade por data (unique index)
    int rentId;
    if (id != null) {
      await db.update(
        _tblRent,
        {
          'data': dia.millisecondsSinceEpoch,
          'percentual': percentual,
          'rendimento_valor': rendimentoValor,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      rentId = id;
    } else {
      rentId = await db.insert(
        _tblRent,
        {
          'data': dia.millisecondsSinceEpoch,
          'percentual': percentual,
          'rendimento_valor': rendimentoValor,
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // remove qualquer movimento auto anterior para a data
    await db.delete(
      _tblMov,
      where: 'origem = ? AND data = ?',
      whereArgs: ['rentabilidade', dia.millisecondsSinceEpoch],
    );

    // cria movimento auto do rendimento
    await db.insert(_tblMov, {
      'data': dia.millisecondsSinceEpoch,
      'tipo': BluminersMovimentoTipo.rendimento.index,
      'carteira': BluminersCarteira.disponivel.index,
      'valor': rendimentoValor,
      'observacao': 'Rendimento (% ao dia)',
      'origem': 'rentabilidade',
      'id_origem': rentId,
      'criado_em': DateTime.now().millisecondsSinceEpoch,
    });

    final row = await db.query(_tblRent, where: 'id = ?', whereArgs: [rentId], limit: 1);
    return BluminersRentabilidade.fromMap(row.first);
  }
}

