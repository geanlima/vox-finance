import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/planejamento_despesa.dart';
import 'package:vox_finance/ui/data/models/planejamento_despesa_item.dart';

class PlanejamentoDespesaRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<PlanejamentoDespesa>> listar() async {
    final db = await _db;
    final rows = await db.query(
      'planejamentos_despesa',
      orderBy: 'data_inicio DESC, id DESC',
    );
    return rows.map(PlanejamentoDespesa.fromMap).toList();
  }

  Future<PlanejamentoDespesa?> getPorId(int id) async {
    final db = await _db;
    final rows = await db.query(
      'planejamentos_despesa',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PlanejamentoDespesa.fromMap(rows.first);
  }

  Future<int> salvar(PlanejamentoDespesa p) async {
    final db = await _db;
    final now = DateTime.now();
    final map = p.toMap()..remove('id');

    if (p.id == null) {
      map['criado_em'] = now.millisecondsSinceEpoch;
      map['atualizado_em'] = now.millisecondsSinceEpoch;
      return db.insert('planejamentos_despesa', map);
    }
    map['atualizado_em'] = now.millisecondsSinceEpoch;
    await db.update(
      'planejamentos_despesa',
      map,
      where: 'id = ?',
      whereArgs: [p.id],
    );
    return p.id!;
  }

  Future<void> excluir(int id) async {
    final db = await _db;
    await db.delete(
      'planejamentos_despesa_itens',
      where: 'planejamento_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'planejamentos_despesa',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PlanejamentoDespesaItem>> listarItens(int planejamentoId) async {
    final db = await _db;
    final rows = await db.query(
      'planejamentos_despesa_itens',
      where: 'planejamento_id = ?',
      whereArgs: [planejamentoId],
      orderBy: 'ordem ASC, id ASC',
    );
    return rows.map(PlanejamentoDespesaItem.fromMap).toList();
  }

  Future<double> somaValoresItens(int planejamentoId) async {
    final db = await _db;
    final r = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(valor), 0) AS t
      FROM planejamentos_despesa_itens
      WHERE planejamento_id = ?
      ''',
      [planejamentoId],
    );
    return ((r.first['t'] as num?) ?? 0).toDouble();
  }

  Future<int> salvarItem(PlanejamentoDespesaItem item) async {
    final db = await _db;
    final map = item.toMap()..remove('id');

    if (item.id == null) {
      return db.insert('planejamentos_despesa_itens', map);
    }
    await db.update(
      'planejamentos_despesa_itens',
      map,
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return item.id!;
  }

  Future<void> excluirItem(int itemId) async {
    final db = await _db;
    await db.delete(
      'planejamentos_despesa_itens',
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<int> proximaOrdem(int planejamentoId) async {
    final db = await _db;
    final r = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(ordem), -1) AS m
      FROM planejamentos_despesa_itens
      WHERE planejamento_id = ?
      ''',
      [planejamentoId],
    );
    return ((r.first['m'] as num?)?.toInt() ?? -1) + 1;
  }

  Future<void> definirLancamentoDoItem({
    required int itemId,
    int? idLancamento,
  }) async {
    final db = await _db;
    final patch = <String, Object?>{'id_lancamento': idLancamento};
    if (idLancamento != null) {
      patch['id_conta_pagar'] = null;
    }
    await db.update(
      'planejamentos_despesa_itens',
      patch,
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> definirContaPagarDoItem({
    required int itemId,
    int? idContaPagar,
  }) async {
    final db = await _db;
    final patch = <String, Object?>{'id_conta_pagar': idContaPagar};
    if (idContaPagar != null) {
      patch['id_lancamento'] = null;
    }
    await db.update(
      'planejamentos_despesa_itens',
      patch,
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> limparVinculosDoItem(int itemId) async {
    final db = await _db;
    await db.update(
      'planejamentos_despesa_itens',
      {'id_lancamento': null, 'id_conta_pagar': null},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Outro item do mesmo planejamento já referencia esse lançamento.
  Future<bool> outroItemDoPlanejamentoUsaLancamento({
    required int planejamentoId,
    required int idLancamento,
    int? excetoItemId,
  }) async {
    final db = await _db;
    final where =
        excetoItemId == null
            ? 'planejamento_id = ? AND id_lancamento = ?'
            : 'planejamento_id = ? AND id_lancamento = ? AND id != ?';
    final args =
        excetoItemId == null
            ? [planejamentoId, idLancamento]
            : [planejamentoId, idLancamento, excetoItemId];
    final rows = await db.query(
      'planejamentos_despesa_itens',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Outro item do mesmo planejamento já referencia essa conta a pagar.
  Future<bool> outroItemDoPlanejamentoUsaContaPagar({
    required int planejamentoId,
    required int idContaPagar,
    int? excetoItemId,
  }) async {
    final db = await _db;
    final where =
        excetoItemId == null
            ? 'planejamento_id = ? AND id_conta_pagar = ?'
            : 'planejamento_id = ? AND id_conta_pagar = ? AND id != ?';
    final args =
        excetoItemId == null
            ? [planejamentoId, idContaPagar]
            : [planejamentoId, idContaPagar, excetoItemId];
    final rows = await db.query(
      'planejamentos_despesa_itens',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
