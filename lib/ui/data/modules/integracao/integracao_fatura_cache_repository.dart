import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/core/utils/money_split.dart';
import 'package:vox_finance/ui/data/models/fatura_api_dto.dart';
import 'package:vox_finance/ui/data/models/integracao_fatura_cache.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';

class IntegracaoFaturaCacheRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  String buildSourceKey({
    required int idCartaoLocal,
    required int ano,
    required int mes,
    required FaturaApiDto f,
  }) {
    final venc = f.dataVencimento?.toIso8601String() ?? '';
    final fech = f.dataFechamento?.toIso8601String() ?? '';
    final payload = jsonEncode({
      'cartao': idCartaoLocal,
      'ano': ano,
      'mes': mes,
      'apiId': f.id ?? '',
      'venc': venc,
      'fech': fech,
      'total': f.valorTotal,
      'desc': f.descricao ?? '',
    });
    return sha1.convert(utf8.encode(payload)).toString();
  }

  Future<IntegracaoFaturaCache?> getBySourceKey(String sourceKey) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntegracaoFaturaCache.fromMap(rows.first);
  }

  Future<IntegracaoFaturaCache?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntegracaoFaturaCache.fromMap(rows.first);
  }

  Future<IntegracaoFaturaCache?> getUltimaPorCartaoPeriodo({
    required int idCartaoLocal,
    required int ano,
    required int mes,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id_cartao_local = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartaoLocal, ano, mes],
      orderBy: 'importado_em DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntegracaoFaturaCache.fromMap(rows.first);
  }

  Future<List<IntegracaoFaturaCache>> listarPorCartaoPeriodo({
    required int idCartaoLocal,
    required int ano,
    required int mes,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id_cartao_local = ? AND ano = ? AND mes = ?',
      whereArgs: [idCartaoLocal, ano, mes],
      orderBy: 'importado_em DESC',
    );
    return rows.map((r) => IntegracaoFaturaCache.fromMap(r)).toList();
  }

  Future<List<IntegracaoFaturaCache>> listarPorCartao({
    required int idCartaoLocal,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache',
      where: 'id_cartao_local = ?',
      whereArgs: [idCartaoLocal],
      orderBy: 'ano DESC, mes DESC, importado_em DESC',
    );
    return rows.map((r) => IntegracaoFaturaCache.fromMap(r)).toList();
  }

  Future<List<IntegracaoFaturaCacheItem>> listarItens(int idFaturaCache) async {
    final db = await _db;
    final rows = await db.query(
      'integracao_faturas_cache_itens',
      where: 'id_fatura_cache = ?',
      whereArgs: [idFaturaCache],
      orderBy: 'data_hora ASC, id ASC',
    );
    return rows.map((r) => IntegracaoFaturaCacheItem.fromMap(r)).toList();
  }

  Future<void> vincularItemComLancamento({
    required int idItem,
    required int? idLancamentoLocal,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache_itens',
      {'id_lancamento_local': idLancamentoLocal},
      where: 'id = ?',
      whereArgs: [idItem],
    );
  }

  Future<void> atualizarDataHoraItens({
    required int idFaturaCache,
    required Map<String, DateTime> dataPorItemApiId,
  }) async {
    if (dataPorItemApiId.isEmpty) return;
    final db = await _db;

    final rows = await db.query(
      'integracao_faturas_cache_itens',
      columns: ['id', 'item_api_id', 'data_hora'],
      where: 'id_fatura_cache = ?',
      whereArgs: [idFaturaCache],
    );
    if (rows.isEmpty) return;

    final batch = db.batch();
    var alterados = 0;
    for (final r in rows) {
      final id = (r['id'] as num?)?.toInt();
      final apiId = r['item_api_id']?.toString();
      if (id == null || apiId == null || apiId.trim().isEmpty) continue;
      final nova = dataPorItemApiId[apiId];
      if (nova == null) continue;
      final atual = (r['data_hora'] as num?)?.toInt();
      final ms = nova.millisecondsSinceEpoch;
      if (atual != null && atual == ms) continue;
      batch.update(
        'integracao_faturas_cache_itens',
        {'data_hora': ms},
        where: 'id = ?',
        whereArgs: [id],
      );
      alterados += 1;
    }
    if (alterados == 0) return;
    await batch.commit(noResult: true);
  }

  Future<void> marcarFaturaComoFechada({
    required int idFaturaCache,
    required int idLancamentoFatura,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache',
      {
        'fechada_em': DateTime.now().millisecondsSinceEpoch,
        'id_lancamento_fatura': idLancamentoFatura,
      },
      where: 'id = ?',
      whereArgs: [idFaturaCache],
    );
  }

  Future<void> reabrirFatura({
    required int idFaturaCache,
  }) async {
    final db = await _db;
    await db.update(
      'integracao_faturas_cache',
      {
        'fechada_em': null,
        'id_lancamento_fatura': null,
      },
      where: 'id = ?',
      whereArgs: [idFaturaCache],
    );
  }

  Future<List<Lancamento>> listarLancamentosCandidatos({
    required int idCartaoLocal,
    required int ano,
    required int mes,
  }) async {
    // Importante: conta_pagar pode vencer em um mês diferente do lançamento (data_hora),
    // então buscamos primeiro por conta_pagar no período e depois carregamos os lançamentos.
    final db = await _db;
    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1).subtract(
      const Duration(milliseconds: 1),
    );

    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT id_lancamento AS id
      FROM conta_pagar
      WHERE id_cartao = ?
        AND id_lancamento IS NOT NULL
        AND grupo_parcelas NOT LIKE 'FATURA_%'
        AND data_vencimento >= ?
        AND data_vencimento <= ?
      ORDER BY data_vencimento ASC
      ''',
      [
        idCartaoLocal,
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
      ],
    );

    if (rows.isEmpty) return [];

    final ids =
        rows.map<int>((r) => (r['id'] as num).toInt()).toSet().toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    final lancRows = await db.query(
      'lancamentos',
      where:
          'id IN ($placeholders) AND id_cartao = ? AND pagamento_fatura = 0',
      whereArgs: [...ids, idCartaoLocal],
      orderBy: 'data_hora ASC',
    );

    return lancRows.map((e) => Lancamento.fromMap(e)).toList();
  }

  /// Lançamentos elegíveis para associação manual na fatura importada: mesmo cartão,
  /// sem filtro de data (compras com conta a pagar ou lançamento de crédito no cartão).
  Future<List<Lancamento>> listarLancamentosParaAssociacaoFatura({
    required int idCartaoLocal,
  }) async {
    final db = await _db;

    final rowsConta = await db.rawQuery(
      '''
      SELECT DISTINCT id_lancamento AS id
      FROM conta_pagar
      WHERE id_cartao = ?
        AND id_lancamento IS NOT NULL
        AND grupo_parcelas NOT LIKE 'FATURA_%'
      ''',
      [idCartaoLocal],
    );

    final idsFromConta = <int>{
      for (final r in rowsConta) (r['id'] as num).toInt(),
    };

    final rowsLanc = await db.query(
      'lancamentos',
      columns: ['id'],
      where: 'id_cartao = ? AND pagamento_fatura = 0',
      whereArgs: [idCartaoLocal],
    );
    final idsDirect = <int>{
      for (final r in rowsLanc)
        if (r['id'] != null) (r['id'] as num).toInt(),
    };

    final allIds = {...idsFromConta, ...idsDirect};
    if (allIds.isEmpty) return [];

    final placeholders = List.filled(allIds.length, '?').join(',');
    final lancRows = await db.query(
      'lancamentos',
      where: 'id IN ($placeholders)',
      whereArgs: allIds.toList(),
      orderBy: 'data_hora ASC',
    );

    return lancRows.map((e) => Lancamento.fromMap(e)).toList();
  }

  /// Auto-match por valor (e proximidade de data, se houver).
  /// Não sobrescreve vínculos existentes a menos que [overwrite] = true.
  Future<int> autoAssociarItens({
    required IntegracaoFaturaCache fatura,
    required bool overwrite,
  }) async {
    final idFaturaCache = fatura.id;
    if (idFaturaCache == null) return 0;

    final itens = await listarItens(idFaturaCache);
    final lancs = await listarLancamentosCandidatos(
      idCartaoLocal: fatura.idCartaoLocal,
      ano: fatura.ano,
      mes: fatura.mes,
    );

    final usados = <int>{};
    for (final it in itens) {
      final lid = it.idLancamentoLocal;
      if (lid != null) usados.add(lid);
    }

    int vinculados = 0;

    for (final it in itens) {
      if (it.id == null) continue;
      if (!overwrite && it.idLancamentoLocal != null) continue;

      final candidatos = lancs
          .where(
            (l) => coincideValorAssociacao(l.valor, it.valor) && l.id != null,
          )
          .where((l) => !usados.contains(l.id!))
          .toList();

      if (candidatos.isEmpty) continue;

      Lancamento escolhido = candidatos.first;
      final dtItem = it.dataHora;
      if (dtItem != null) {
        candidatos.sort((a, b) {
          final da = (a.dataHora.difference(dtItem).inMinutes).abs();
          final db = (b.dataHora.difference(dtItem).inMinutes).abs();
          return da.compareTo(db);
        });
        escolhido = candidatos.first;
      }

      await vincularItemComLancamento(
        idItem: it.id!,
        idLancamentoLocal: escolhido.id!,
      );
      usados.add(escolhido.id!);
      vinculados += 1;
    }

    return vinculados;
  }

  /// Salva a fatura e seus itens.
  /// Se [overwrite] for true e existir registro com o mesmo source_key, substitui.
  Future<int> salvarFaturaFromApi({
    required int idCartaoLocal,
    required String codigoCartaoApi,
    required int ano,
    required int mes,
    required FaturaApiDto f,
    required bool overwrite,
  }) async {
    final db = await _db;
    final sourceKey = buildSourceKey(
      idCartaoLocal: idCartaoLocal,
      ano: ano,
      mes: mes,
      f: f,
    );

    return db.transaction<int>((txn) async {
      final existing = await txn.query(
        'integracao_faturas_cache',
        where: 'source_key = ?',
        whereArgs: [sourceKey],
        limit: 1,
      );

      int? idCache;
      if (existing.isNotEmpty) {
        idCache = existing.first['id'] as int;
        if (!overwrite) {
          return idCache;
        }
        // Preserva associações quando possível (por item_api_id).
        final vinculosAntigos = await _mapearVinculosItensPorApiId(
          txn,
          idCache,
        );

        await txn.delete(
          'integracao_faturas_cache_itens',
          where: 'id_fatura_cache = ?',
          whereArgs: [idCache],
        );
        await txn.update(
          'integracao_faturas_cache',
          {
            'source_key': sourceKey,
            'codigo_cartao_api': codigoCartaoApi,
            'ano': ano,
            'mes': mes,
            'fatura_api_id': f.id,
            'descricao': f.descricao,
            'valor_total': f.valorTotal,
            'data_vencimento': f.dataVencimento?.millisecondsSinceEpoch,
            'data_fechamento': f.dataFechamento?.millisecondsSinceEpoch,
            'pago': f.pago == null ? null : (f.pago! ? 1 : 0),
            'importado_em': DateTime.now().millisecondsSinceEpoch,
            // Se reimportar, consideramos que precisa "refechar" se desejar.
            'fechada_em': null,
            'id_lancamento_fatura': null,
          },
          where: 'id = ?',
          whereArgs: [idCache],
        );

        await _inserirItensFromApi(
          txn,
          idCache,
          f,
          vinculosAntigos: vinculosAntigos,
        );
      } else {
        idCache = await txn.insert(
          'integracao_faturas_cache',
          {
            'source_key': sourceKey,
            'id_cartao_local': idCartaoLocal,
            'codigo_cartao_api': codigoCartaoApi,
            'ano': ano,
            'mes': mes,
            'fatura_api_id': f.id,
            'descricao': f.descricao,
            'valor_total': f.valorTotal,
            'data_vencimento': f.dataVencimento?.millisecondsSinceEpoch,
            'data_fechamento': f.dataFechamento?.millisecondsSinceEpoch,
            'pago': f.pago == null ? null : (f.pago! ? 1 : 0),
            'importado_em': DateTime.now().millisecondsSinceEpoch,
            'fechada_em': null,
            'id_lancamento_fatura': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _inserirItensFromApi(txn, idCache, f);
      }

      return idCache;
    });
  }

  Future<Map<String, int>> _mapearVinculosItensPorApiId(
    DatabaseExecutor txn,
    int idFaturaCache,
  ) async {
    final rows = await txn.query(
      'integracao_faturas_cache_itens',
      columns: ['item_api_id', 'id_lancamento_local'],
      where: 'id_fatura_cache = ?',
      whereArgs: [idFaturaCache],
    );

    final map = <String, int>{};
    for (final r in rows) {
      final apiId = r['item_api_id']?.toString().trim();
      final idLanc = (r['id_lancamento_local'] as num?)?.toInt();
      if (apiId == null || apiId.isEmpty) continue;
      if (idLanc == null) continue;
      map[apiId] = idLanc;
    }
    return map;
  }

  Future<void> _inserirItensFromApi(
    DatabaseExecutor txn,
    int idCache,
    FaturaApiDto f, {
    Map<String, int> vinculosAntigos = const {},
  }) async {
    final batch = txn.batch();
    for (final it in f.lancamentos) {
      final apiId = it.id?.toString().trim();
      final idLancamentoLocal =
          (apiId != null && apiId.isNotEmpty) ? vinculosAntigos[apiId] : null;
      batch.insert(
        'integracao_faturas_cache_itens',
        {
          'id_fatura_cache': idCache,
          'id_lancamento_local': idLancamentoLocal,
          'item_api_id': it.id,
          'descricao': it.descricao,
          'valor': it.valor,
          'data_hora': it.dataHora?.millisecondsSinceEpoch,
          'categoria': it.categoria,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deletarFaturaCache(int idFaturaCache) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'integracao_faturas_cache_itens',
        where: 'id_fatura_cache = ?',
        whereArgs: [idFaturaCache],
      );
      await txn.delete(
        'integracao_faturas_cache',
        where: 'id = ?',
        whereArgs: [idFaturaCache],
      );
    });
  }
}

