import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';

enum InvestimentoCdiMovimentoTipo { saque, aporte }

class InvestimentoCdiMovimentoRow {
  final int id;
  final int idCarteira;
  final DateTime data;
  final InvestimentoCdiMovimentoTipo tipo;
  final double valor;
  final int? idLancamento;

  const InvestimentoCdiMovimentoRow({
    required this.id,
    required this.idCarteira,
    required this.data,
    required this.tipo,
    required this.valor,
    required this.idLancamento,
  });
}

class InvestimentoCdiMovimentosRepository {
  static const _tbl = 'investimento_cdi_movimentos';
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<InvestimentoCdiMovimentoRow>> listarPorCarteira(
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
    int? inull(Object? v) => (v as num?)?.toInt();

    return rows.map((m) {
      final tipoRaw = i(m['tipo']);
      final tipo =
          (tipoRaw == 1) ? InvestimentoCdiMovimentoTipo.aporte : InvestimentoCdiMovimentoTipo.saque;
      return InvestimentoCdiMovimentoRow(
        id: i(m['id']),
        idCarteira: i(m['id_carteira']),
        data: DateTime.fromMillisecondsSinceEpoch(i(m['data'])),
        tipo: tipo,
        valor: d(m['valor']),
        idLancamento: inull(m['id_lancamento']),
      );
    }).toList();
  }

  Future<void> inserir({
    required int idCarteira,
    required DateTime data,
    required InvestimentoCdiMovimentoTipo tipo,
    required double valor,
    int? idLancamento,
  }) async {
    final db = await _db;
    final dia = DateTime(data.year, data.month, data.day);
    await db.insert(
      _tbl,
      {
        'id_carteira': idCarteira,
        'data': dia.millisecondsSinceEpoch,
        'tipo': tipo.index,
        'valor': valor,
        'id_lancamento': idLancamento,
        'criado_em': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deletarPorCarteira(int idCarteira) async {
    final db = await _db;
    await db.delete(_tbl, where: 'id_carteira = ?', whereArgs: [idCarteira]);
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete(_tbl, where: 'id = ?', whereArgs: [id]);
  }
}

