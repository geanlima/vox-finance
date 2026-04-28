import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';

class InvestimentoCdiRendimentoRow {
  final int id;
  final int idCarteira;
  final DateTime data;
  final double base;
  final double pctCdi;
  final double rendimentoValor;
  final int? idLancamento;

  const InvestimentoCdiRendimentoRow({
    required this.id,
    required this.idCarteira,
    required this.data,
    required this.base,
    required this.pctCdi,
    required this.rendimentoValor,
    required this.idLancamento,
  });
}

class InvestimentoCdiRendimentosRepository {
  static const _tbl = 'investimento_cdi_rendimentos';
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<({int ano, int mes, double total})>> totalPorMes(
    int idCarteira, {
    int limit = 24,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        CAST(strftime('%Y', datetime(data/1000, 'unixepoch')) AS INTEGER) AS ano,
        CAST(strftime('%m', datetime(data/1000, 'unixepoch')) AS INTEGER) AS mes,
        SUM(rendimento_valor) AS total
      FROM $_tbl
      WHERE id_carteira = ?
      GROUP BY ano, mes
      ORDER BY ano DESC, mes DESC
      LIMIT ?
    ''', [idCarteira, limit]);

    double d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    return rows
        .map(
          (r) => (ano: i(r['ano']), mes: i(r['mes']), total: d(r['total'])),
        )
        .toList();
  }

  Future<List<int>> listarIdsLancamentoPorCarteira(int idCarteira) async {
    final db = await _db;
    final rows = await db.query(
      _tbl,
      columns: ['id_lancamento'],
      where: 'id_carteira = ? AND id_lancamento IS NOT NULL',
      whereArgs: [idCarteira],
    );
    final out = <int>[];
    for (final r in rows) {
      final id = r['id_lancamento'];
      if (id is int) out.add(id);
    }
    return out;
  }

  Future<void> deletarPorCarteira(int idCarteira) async {
    final db = await _db;
    await db.delete(_tbl, where: 'id_carteira = ?', whereArgs: [idCarteira]);
  }

  Future<List<InvestimentoCdiRendimentoRow>> listarPorCarteira(
    int idCarteira, {
    int limit = 400,
  }) async {
    final db = await _db;
    final rows = await db.query(
      _tbl,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
      orderBy: 'data DESC, id DESC',
      limit: limit,
    );

    double d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    return rows
        .map(
          (m) => InvestimentoCdiRendimentoRow(
            id: i(m['id']),
            idCarteira: i(m['id_carteira']),
            data: DateTime.fromMillisecondsSinceEpoch(i(m['data'])),
            base: d(m['base']),
            pctCdi: d(m['pct_cdi']),
            rendimentoValor: d(m['rendimento_valor']),
            idLancamento: m['id_lancamento'] as int?,
          ),
        )
        .toList();
  }

  Future<DateTime?> ultimaDataProcessada(int idCarteira) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT MAX(data) AS d
      FROM $_tbl
      WHERE id_carteira = ?
    ''', [idCarteira]);
    final ms = rows.first['d'] as int?;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> inserir({
    required int idCarteira,
    required DateTime data,
    required double base,
    required double pctCdi,
    required double rendimentoValor,
    required int? idLancamento,
  }) async {
    final db = await _db;
    final dia = DateTime(data.year, data.month, data.day);
    await db.insert(
      _tbl,
      {
        'id_carteira': idCarteira,
        'data': dia.millisecondsSinceEpoch,
        'base': base,
        'pct_cdi': pctCdi,
        'rendimento_valor': rendimentoValor,
        'id_lancamento': idLancamento,
        'criado_em': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> atualizarRendimentoValor({
    required int id,
    required double rendimentoValor,
  }) async {
    final db = await _db;
    await db.update(
      _tbl,
      {'rendimento_valor': rendimentoValor},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete(_tbl, where: 'id = ?', whereArgs: [id]);
  }
}

