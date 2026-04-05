import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/bluminers_config.dart';
import 'package:vox_finance/ui/data/models/bluminers_movimento.dart';
import 'package:vox_finance/ui/data/models/bluminers_rentabilidade.dart';

class BluminersRepository {
  static const _tblConfig = 'investimento_bluminers_config';
  static const _tblMov = 'investimento_bluminers_movimentos';
  static const _tblRent = 'investimento_bluminers_rentabilidade';

  final int idCarteira;

  BluminersRepository({required this.idCarteira});

  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<BluminersConfig> getConfig() async {
    final db = await _db;
    final rows = await db.query(
      _tblConfig,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
      limit: 1,
    );
    if (rows.isEmpty) {
      final cfg = BluminersConfig(
        idCarteira: idCarteira,
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
    final rows = await db.query(
      _tblMov,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
      orderBy: 'data DESC, id DESC',
    );
    return rows.map((e) => BluminersMovimento.fromMap(e)).toList();
  }

  Future<int> salvarMovimento(BluminersMovimento mov) async {
    final db = await _db;
    final map = Map<String, Object?>.from(mov.toMap())
      ..['id_carteira'] = idCarteira;
    if (mov.id == null) {
      map.remove('id');
      return db.insert(_tblMov, map);
    }
    map.remove('id');
    return db.update(
      _tblMov,
      map,
      where: 'id = ? AND id_carteira = ?',
      whereArgs: [mov.id, idCarteira],
    );
  }

  Future<void> deletarMovimento(int id) async {
    final db = await _db;
    await db.delete(
      _tblMov,
      where: 'id = ? AND id_carteira = ?',
      whereArgs: [id, idCarteira],
    );
  }

  Future<List<BluminersRentabilidade>> listarRentabilidade() async {
    final db = await _db;
    final rows = await db.query(
      _tblRent,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
      orderBy: 'data DESC, id DESC',
    );
    return rows.map((e) => BluminersRentabilidade.fromMap(e)).toList();
  }

  Future<void> deletarRentabilidade(BluminersRentabilidade item) async {
    final db = await _db;
    final diaMs =
        DateTime(item.data.year, item.data.month, item.data.day).millisecondsSinceEpoch;
    if (item.id != null) {
      await db.delete(
        _tblRent,
        where: 'id = ? AND id_carteira = ?',
        whereArgs: [item.id, idCarteira],
      );
    } else {
      await db.delete(
        _tblRent,
        where: 'data = ? AND id_carteira = ?',
        whereArgs: [diaMs, idCarteira],
      );
    }

    if (item.id != null) {
      await db.delete(
        _tblMov,
        where: 'origem = ? AND id_origem = ? AND id_carteira = ?',
        whereArgs: ['rentabilidade', item.id, idCarteira],
      );
    } else {
      await db.delete(
        _tblMov,
        where: 'origem = ? AND data = ? AND id_carteira = ?',
        whereArgs: ['rentabilidade', diaMs, idCarteira],
      );
    }
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
      WHERE id_carteira = ? AND data $op ?
      GROUP BY carteira
    ''', [
      BluminersMovimentoTipo.aporte.index,
      BluminersMovimentoTipo.saque.index,
      BluminersMovimentoTipo.rendimento.index,
      BluminersMovimentoTipo.ajuste.index,
      idCarteira,
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

    final tsDia = dia.millisecondsSinceEpoch;
    final rowsDia = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS aportes_inv,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS ajustes_inv,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS saques_disp,
        COALESCE(SUM(CASE WHEN tipo = ? AND carteira = ? THEN valor ELSE 0 END), 0) AS ajustes_disp
      FROM $_tblMov
      WHERE id_carteira = ? AND data = ?
    ''', [
      BluminersMovimentoTipo.aporte.index,
      BluminersCarteira.investido.index,
      BluminersMovimentoTipo.ajuste.index,
      BluminersCarteira.investido.index,
      BluminersMovimentoTipo.saque.index,
      BluminersCarteira.disponivel.index,
      BluminersMovimentoTipo.ajuste.index,
      BluminersCarteira.disponivel.index,
      idCarteira,
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

    int rentId;
    if (id != null) {
      await db.update(
        _tblRent,
        {
          'data': dia.millisecondsSinceEpoch,
          'percentual': percentual,
          'rendimento_valor': rendimentoValor,
        },
        where: 'id = ? AND id_carteira = ?',
        whereArgs: [id, idCarteira],
      );
      rentId = id;
    } else {
      rentId = await db.insert(
        _tblRent,
        {
          'id_carteira': idCarteira,
          'data': dia.millisecondsSinceEpoch,
          'percentual': percentual,
          'rendimento_valor': rendimentoValor,
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await db.delete(
      _tblMov,
      where: 'origem = ? AND data = ? AND id_carteira = ?',
      whereArgs: ['rentabilidade', dia.millisecondsSinceEpoch, idCarteira],
    );

    await db.insert(_tblMov, {
      'id_carteira': idCarteira,
      'data': dia.millisecondsSinceEpoch,
      'tipo': BluminersMovimentoTipo.rendimento.index,
      'carteira': BluminersCarteira.disponivel.index,
      'valor': rendimentoValor,
      'observacao': 'Rendimento (% ao dia)',
      'origem': 'rentabilidade',
      'id_origem': rentId,
      'criado_em': DateTime.now().millisecondsSinceEpoch,
    });

    final row = await db.query(
      _tblRent,
      where: 'id = ? AND id_carteira = ?',
      whereArgs: [rentId, idCarteira],
      limit: 1,
    );
    return BluminersRentabilidade.fromMap(row.first);
  }
}
