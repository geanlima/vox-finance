import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco_oferta.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco_oferta_historico.dart';

class MonitoramentoPrecoRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<void> _recalcularPrecoAtualDaLoja(Database db, int idOferta) async {
    final rows = await db.query(
      'monitoramento_precos_ofertas_historico',
      where: 'id_oferta = ?',
      whereArgs: [idOferta],
      orderBy: 'criado_em DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'monitoramento_precos_ofertas',
        {'preco': 0.0, 'atualizado_em': now},
        where: 'id = ?',
        whereArgs: [idOferta],
      );
      return;
    }

    final r = rows.first;
    final preco = (r['preco'] as num).toDouble();
    final whenMs = (r['criado_em'] as num).toInt();
    await db.update(
      'monitoramento_precos_ofertas',
      {'preco': preco, 'atualizado_em': whenMs},
      where: 'id = ?',
      whereArgs: [idOferta],
    );
  }

  Future<List<MonitoramentoPreco>> listarProdutos() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        p.*,
        COUNT(o.id) AS ofertas_count,
        MIN(CASE WHEN o.preco > 0 THEN o.preco ELSE NULL END) AS menor_preco,
        MAX(COALESCE(o.atualizado_em, p.atualizado_em)) AS atualizado_em_calc
      FROM monitoramento_precos p
      LEFT JOIN monitoramento_precos_ofertas o
        ON o.id_monitoramento = p.id
      GROUP BY p.id
      ORDER BY atualizado_em_calc DESC, p.id DESC;
    ''');
    return rows.map((r) => MonitoramentoPreco.fromMap(r)).toList();
  }

  Future<int> salvar(MonitoramentoPreco item) async {
    final db = await _db;
    final dados = item.toMap()..remove('id');

    if (item.id == null) {
      final id = await db.insert(
        'monitoramento_precos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    }

    await db.update(
      'monitoramento_precos',
      dados,
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return item.id!;
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete(
      'monitoramento_precos_ofertas',
      where: 'id_monitoramento = ?',
      whereArgs: [id],
    );
    await db.delete('monitoramento_precos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MonitoramentoPrecoOferta>> listarOfertas(int idMonitoramento) async {
    final db = await _db;
    final rows = await db.query(
      'monitoramento_precos_ofertas',
      where: 'id_monitoramento = ?',
      whereArgs: [idMonitoramento],
      orderBy: 'preco ASC, atualizado_em DESC',
    );
    return rows.map((r) => MonitoramentoPrecoOferta.fromMap(r)).toList();
  }

  /// Salva/atualiza a loja/oferta (metadados). Não grava histórico.
  Future<int> salvarLoja(MonitoramentoPrecoOferta oferta) async {
    final db = await _db;
    final dados = oferta.toMap()..remove('id');

    if (oferta.id == null) {
      final id = await db.insert(
        'monitoramento_precos_ofertas',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    }

    await db.update(
      'monitoramento_precos_ofertas',
      dados,
      where: 'id = ?',
      whereArgs: [oferta.id],
    );
    return oferta.id!;
  }

  Future<void> adicionarPreco({
    required int idOferta,
    required double preco,
    required DateTime dataHora,
  }) async {
    final db = await _db;
    final ms = dataHora.millisecondsSinceEpoch;

    await db.insert(
      'monitoramento_precos_ofertas_historico',
      {
        'id_oferta': idOferta,
        'preco': preco,
        'criado_em': ms,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.update(
      'monitoramento_precos_ofertas',
      {'preco': preco, 'atualizado_em': ms},
      where: 'id = ?',
      whereArgs: [idOferta],
    );
  }

  Future<List<MonitoramentoPrecoOfertaHistorico>> listarHistoricoPorOferta(
    int idOferta,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'monitoramento_precos_ofertas_historico',
      where: 'id_oferta = ?',
      whereArgs: [idOferta],
      orderBy: 'criado_em DESC',
    );
    return rows.map((r) => MonitoramentoPrecoOfertaHistorico.fromMap(r)).toList();
  }

  Future<void> atualizarPrecoHistorico({
    required int idHistorico,
    required int idOferta,
    required double preco,
    required DateTime dataHora,
  }) async {
    final db = await _db;
    await db.update(
      'monitoramento_precos_ofertas_historico',
      {
        'preco': preco,
        'criado_em': dataHora.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [idHistorico],
    );
    await _recalcularPrecoAtualDaLoja(db, idOferta);
  }

  Future<void> deletarPrecoHistorico({
    required int idHistorico,
    required int idOferta,
  }) async {
    final db = await _db;
    await db.delete(
      'monitoramento_precos_ofertas_historico',
      where: 'id = ?',
      whereArgs: [idHistorico],
    );
    await _recalcularPrecoAtualDaLoja(db, idOferta);
  }

  Future<void> deletarOferta(int idOferta) async {
    final db = await _db;
    await db.delete(
      'monitoramento_precos_ofertas_historico',
      where: 'id_oferta = ?',
      whereArgs: [idOferta],
    );
    await db.delete(
      'monitoramento_precos_ofertas',
      where: 'id = ?',
      whereArgs: [idOferta],
    );
  }

  Future<List<MonitoramentoPrecoOfertaHistorico>> listarHistoricoPorProduto(
    int idMonitoramento,
  ) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT h.*
      FROM monitoramento_precos_ofertas_historico h
      JOIN monitoramento_precos_ofertas o ON o.id = h.id_oferta
      WHERE o.id_monitoramento = ?
      ORDER BY h.criado_em ASC
    ''',
      [idMonitoramento],
    );
    return rows.map((r) => MonitoramentoPrecoOfertaHistorico.fromMap(r)).toList();
  }

  /// Retorna pontos do histórico já com a "loja" (label) de cada oferta.
  /// Útil para gráfico por loja.
  Future<List<Map<String, Object?>>> listarHistoricoPorProdutoComLoja(
    int idMonitoramento,
  ) async {
    final db = await _db;
    return db.rawQuery(
      '''
      SELECT
        h.id_oferta,
        h.preco,
        h.criado_em,
        o.loja
      FROM monitoramento_precos_ofertas_historico h
      JOIN monitoramento_precos_ofertas o ON o.id = h.id_oferta
      WHERE o.id_monitoramento = ?
      ORDER BY h.criado_em ASC
    ''',
      [idMonitoramento],
    );
  }
}

