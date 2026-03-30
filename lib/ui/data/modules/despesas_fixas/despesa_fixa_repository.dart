import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa.dart';

class DespesaFixaRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<DespesaFixa>> listar() async {
    final db = await _db;
    final rows = await db.query('despesas_fixas', orderBy: 'descricao ASC');
    return rows.map((e) => DespesaFixa.fromMap(e)).toList();
  }

  Future<int> salvar(DespesaFixa item) async {
    final db = await _db;
    if (item.id == null) {
      final dados = item.toMap()..remove('id');
      return db.insert('despesas_fixas', dados);
    }
    return db.update(
      'despesas_fixas',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('despesas_fixas', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> gerarPendenciasDoMes(DateTime referencia) async {
    final db = await _db;
    final anoMes =
        '${referencia.year.toString().padLeft(4, '0')}${referencia.month.toString().padLeft(2, '0')}';

    final fixas = await db.query(
      'despesas_fixas',
      where: 'ativo = 1 AND gerar_automatico = 1',
    );

    int criadas = 0;
    for (final row in fixas) {
      final fixa = DespesaFixa.fromMap(row);
      if (fixa.id == null) continue;

      final grupo = 'FIXA_${fixa.id}_$anoMes';
      final existe = await db.query(
        'conta_pagar',
        columns: ['id'],
        where: 'grupo_parcelas = ?',
        whereArgs: [grupo],
        limit: 1,
      );
      if (existe.isNotEmpty) continue;

      final ultimoDia = DateTime(referencia.year, referencia.month + 1, 0).day;
      final dia = fixa.diaVencimento.clamp(1, ultimoDia);
      final venc = DateTime(referencia.year, referencia.month, dia);

      final conta = ContaPagar(
        descricao: fixa.descricao,
        valor: fixa.valor,
        dataVencimento: venc,
        pago: false,
        grupoParcelas: grupo,
        parcelaNumero: 1,
        parcelaTotal: 1,
        formaPagamento: fixa.formaPagamento,
      );

      final dados = conta.toMap()..remove('id');
      await db.insert('conta_pagar', dados, conflictAlgorithm: ConflictAlgorithm.ignore);
      criadas++;
    }

    return criadas;
  }
}

