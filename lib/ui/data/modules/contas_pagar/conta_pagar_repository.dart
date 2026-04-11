// lib/ui/data/modules/contas_pagar/conta_pagar_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/utils/money_split.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';

class ContaPagarRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  // ============================================================
  //  C R U D   B Á S I C O
  // ============================================================
  Future<void> deletarPorId(int id) async {
    final db = await _db;
    await db.delete('contas_pagar', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> salvar(ContaPagar conta) async {
    final db = await _db;

    if (conta.id == null) {
      final id = await db.insert(
        'conta_pagar',
        conta.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      conta.id = id;
      return id;
    } else {
      return db.update(
        'conta_pagar',
        conta.toMap(),
        where: 'id = ?',
        whereArgs: [conta.id],
      );
    }
  }

  /// Cria ou atualiza a conta a pagar **da fatura de cartão**,
  /// usando o `id_lancamento` como vínculo 1:1.
  ///
  /// - Lê o lançamento na tabela `lancamentos`
  /// - Copia: descrição, valor, data_vencimento, pago, data_pagamento,
  ///   grupo_parcelas, parcela_numero, parcela_total, id_cartao
  /// - Garante preenchimento de campos NOT NULL (`grupo_parcelas`,
  ///   `parcela_numero`, `parcela_total`).
  /// Cria ou atualiza a conta a pagar vinculada a uma **fatura de cartão**.
  /// Usa o campo `id_lancamento` como vínculo (1:1 com o lançamento de fatura).
  Future<void> upsertContaPagarDaFatura({
    required int idLancamento,
    required String descricao,
    required double valor,
    required DateTime dataVencimento,
    int? idCartao,
  }) async {
    final db = await _db;

    final vencimentoMs = dataVencimento.millisecondsSinceEpoch;

    // 🔹 grupo único para esta fatura (idCartao + ano + mês)
    final ano = dataVencimento.year.toString().padLeft(4, '0');
    final mes = dataVencimento.month.toString().padLeft(2, '0');
    final grupoParcelas = 'FATURA_${idCartao ?? 0}_$ano$mes';

    // Verifica se já existe conta_pagar vinculada ao lançamento
    final existente = await db.query(
      'conta_pagar',
      where: 'id_lancamento = ?',
      whereArgs: [idLancamento],
      limit: 1,
    );

    final dados = <String, Object?>{
      'descricao': descricao,
      'valor': valor,
      'data_vencimento': vencimentoMs,
      'pago': 0,
      'data_pagamento': null,
      'id_lancamento': idLancamento,
      'grupo_parcelas': grupoParcelas,
      'parcela_numero': 1,
      'parcela_total': 1,
    };

    if (idCartao != null) {
      dados['id_cartao'] = idCartao;
    }

    if (existente.isNotEmpty) {
      await db.update(
        'conta_pagar',
        dados,
        where: 'id_lancamento = ?',
        whereArgs: [idLancamento],
      );
    } else {
      await db.insert('conta_pagar', dados);
    }
  }

  // ============================================================
  //  M A R C A R   C O M O   P A G O
  // ============================================================

  Future<void> marcarComoPagoPorCartaoEVencimento({
    required int idCartao,
    required DateTime dataVencimento,
    required bool pago,
  }) async {
    final db = await _db;

    await db.update(
      'conta_pagar',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id_cartao = ? AND data_vencimento = ?',
      whereArgs: [idCartao, dataVencimento.millisecondsSinceEpoch],
    );
  }

  Future<void> marcarComoPagoPorLancamentoId(
    int idLancamento,
    bool pago,
  ) async {
    final db = await _db;

    await db.update(
      'conta_pagar',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id_lancamento = ?',
      whereArgs: [idLancamento],
    );
  }

  Future<void> marcarParcelaComoPaga(int id, bool pago) async {
    final db = await _db;
    await db.update(
      'conta_pagar',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> atualizarValorParcela(int id, double valor) async {
    final db = await _db;
    await db.update(
      'conta_pagar',
      {'valor': valor},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Atualiza descrição, valor (repartido igualmente entre as parcelas) e datas de
  /// vencimento (1 parcela por mês a partir de [primeiraDataVencimento], igual ao fluxo de criação).
  ///
  /// **Não** altera a tabela `lancamentos`: mantém `id_lancamento`, `grupo_parcelas`,
  /// `pago`, `data_pagamento`, forma/cartão/conta em cada linha.
  Future<void> atualizarGrupoContasPagarExistente({
    required String grupoParcelas,
    required String descricao,
    required double valorTotal,
    required DateTime primeiraDataVencimento,
  }) async {
    final parcelas = await getParcelasPorGrupo(grupoParcelas);
    if (parcelas.isEmpty) return;

    parcelas.sort((a, b) {
      final pa = a.parcelaNumero ?? 0;
      final pb = b.parcelaNumero ?? 0;
      return pa.compareTo(pb);
    });

    final n = parcelas.length;
    if (n <= 0 || valorTotal <= 0) return;

    final valoresParcela = splitTotalEmPartesIguais(valorTotal, n);

    // Mesma lógica de [IAService.salvarContasParceladas]: 1º vencimento, +1 mês por parcela.
    for (var i = 0; i < parcelas.length; i++) {
      final p = parcelas[i];
      final venc = DateTime(
        primeiraDataVencimento.year,
        primeiraDataVencimento.month + i,
        primeiraDataVencimento.day,
      );

      p.descricao = descricao;
      p.valor = valoresParcela[i];
      p.dataVencimento = venc;
      if (p.parcelaTotal != null) {
        p.parcelaTotal = n;
      }
      await salvar(p);
    }
  }

  /// Atualiza valor, descrição e forma nas parcelas **ainda não pagas** geradas pela
  /// despesa fixa (`grupo_parcelas` = `FIXA_{id}_YYYYMM`), para refletir o cadastro.
  Future<void> atualizarContasAbertasDaDespesaFixa({
    required int idDespesaFixa,
    required double valor,
    required String descricao,
    int? formaPagamentoIndex,
  }) async {
    final db = await _db;
    final dados = <String, Object?>{
      'valor': valor,
      'descricao': descricao,
      'forma_pagamento': formaPagamentoIndex,
    };
    await db.update(
      'conta_pagar',
      dados,
      where: 'grupo_parcelas LIKE ? AND pago = 0',
      whereArgs: ['FIXA_${idDespesaFixa}_%'],
    );
  }

  /// Útil para sincronizar com lançamento (grupo + nº parcela)
  Future<void> marcarPorGrupoEParcela({
    required String grupo,
    required int parcelaNumero,
    required bool pago,
  }) async {
    final db = await _db;

    await db.update(
      'conta_pagar',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'grupo_parcelas = ? AND parcela_numero = ?',
      whereArgs: [grupo, parcelaNumero],
    );
  }

  // ============================================================
  //  C O N S U L T A S
  // ============================================================

  Future<List<ContaPagar>> getTodas() async {
    final db = await _db;
    final result = await db.query(
      'conta_pagar',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<List<ContaPagar>> getPendentes() async {
    final db = await _db;
    final result = await db.query(
      'conta_pagar',
      where: 'pago = 0',
      orderBy: 'data_vencimento ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<List<ContaPagar>> getParcelasPorGrupo(String grupo) async {
    final db = await _db;
    final result = await db.query(
      'conta_pagar',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      orderBy: 'parcela_numero ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  // ============================================================
  //  D E L E T E
  // ============================================================

  /// Deleta uma conta a pagar pelo ID
  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('conta_pagar', where: 'id = ?', whereArgs: [id]);
  }

  /// Deleta todas as parcelas de um grupo (ex.: ao remover uma compra parcelada inteira)
  Future<void> deletarPorGrupo(String grupo) async {
    final db = await _db;
    await db.delete(
      'conta_pagar',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
    );
  }

  /// Deleta apenas uma parcela específica pelo grupo + nº parcela
  Future<void> deletarPorGrupoEParcela({
    required String grupo,
    required int parcelaNumero,
  }) async {
    final db = await _db;
    await db.delete(
      'conta_pagar',
      where: 'grupo_parcelas = ? AND parcela_numero = ?',
      whereArgs: [grupo, parcelaNumero],
    );
  }
}
