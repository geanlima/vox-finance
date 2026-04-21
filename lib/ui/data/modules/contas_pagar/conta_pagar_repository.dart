// lib/ui/data/modules/contas_pagar/conta_pagar_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/utils/money_split.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

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
  /// Para cada parcela, alinha [Lancamento.dataHora] ao novo vencimento quando houver
  /// lançamento vinculado (`id_lancamento`, mesmo `grupo_parcelas` ou correspondência
  /// por vencimento/valor/descrição anteriores).
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
      final antes = ContaPagar.fromMap(p.toMap());
      final cab = p.dataCabecalho;
      final venc = DateTime(
        primeiraDataVencimento.year,
        primeiraDataVencimento.month + i,
        primeiraDataVencimento.day,
      );

      p.descricao = descricao;
      p.valor = valoresParcela[i];
      p.dataVencimento = venc;
      p.dataCabecalho = cab;
      if (p.parcelaTotal != null) {
        p.parcelaTotal = n;
      }
      await salvar(p);
      await sincronizarDataHoraLancamentoAposEditarConta(
        contaAtualizada: p,
        contaAntesEdicao: antes,
      );
    }
  }

  /// Descrição, valor total e **data do cabeçalho** em todas as linhas.
  /// Não altera [ContaPagar.dataVencimento] nem lançamentos.
  Future<void> atualizarCabecalhoGrupoContasPagar({
    required String grupoParcelas,
    required String descricao,
    required double valorTotal,
    required DateTime dataCabecalho,
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
    final cab = DateTime(
      dataCabecalho.year,
      dataCabecalho.month,
      dataCabecalho.day,
    );

    for (var i = 0; i < n; i++) {
      final p = parcelas[i];
      p.descricao = descricao;
      p.valor = valoresParcela[i];
      p.dataCabecalho = cab;
      await salvar(p);
    }
  }

  /// Grupos cuja **data de cabeçalho** (ou 1º vencimento se cabeçalho for nulo) cai em [dia].
  Future<List<ContaPagarGrupoPlanejamento>> listarGruposPorDataCabecalhoPlanejamento(
    DateTime dia,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'conta_pagar',
      where: 'grupo_parcelas NOT LIKE ?',
      whereArgs: ['FATURA_%'],
    );
    final todas = rows.map(ContaPagar.fromMap).toList();
    final mapa = <String, List<ContaPagar>>{};
    for (final c in todas) {
      mapa.putIfAbsent(c.grupoParcelas, () => []).add(c);
    }

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));
    final inicioMs = inicio.millisecondsSinceEpoch;
    final fimMs = fim.millisecondsSinceEpoch;

    final out = <ContaPagarGrupoPlanejamento>[];
    for (final e in mapa.entries) {
      final parcelas = e.value;
      parcelas.sort((a, b) {
        final pa = a.parcelaNumero ?? 999999;
        final pb = b.parcelaNumero ?? 999999;
        return pa.compareTo(pb);
      });
      final primeira = parcelas.first;
      final ref = primeira.dataCabecalho ?? primeira.dataVencimento;
      final refDia = DateTime(ref.year, ref.month, ref.day);
      final refMs = refDia.millisecondsSinceEpoch;
      if (refMs < inicioMs || refMs >= fimMs) continue;

      final primeiroVenc = parcelas
          .map((c) => c.dataVencimento)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final vt = parcelas.fold<double>(0, (s, c) => s + c.valor);
      out.add(
        ContaPagarGrupoPlanejamento(
          grupoParcelas: e.key,
          descricao: primeira.descricao,
          valorTotal: vt,
          quantidadeParcelas: parcelas.length,
          dataCabecalho: primeira.dataCabecalho ?? primeira.dataVencimento,
          primeiroVencimento: primeiroVenc,
        ),
      );
    }
    return out;
  }

  /// Primeira parcela do grupo cujo `id` não está em [idsOcupados].
  Future<int?> primeiroIdContaLivreNoGrupo(
    String grupoParcelas,
    Set<int> idsOcupados,
  ) async {
    final parcelas = await getParcelasPorGrupo(grupoParcelas);
    parcelas.sort((a, b) {
      final pa = a.parcelaNumero ?? 0;
      final pb = b.parcelaNumero ?? 0;
      return pa.compareTo(pb);
    });
    for (final p in parcelas) {
      final id = p.id;
      if (id != null && !idsOcupados.contains(id)) return id;
    }
    return null;
  }

  /// Igual a [atualizarGrupoContasPagarExistente], mas permite mudar a **quantidade**
  /// de parcelas: remove linhas extras (só se não pagas) e cria novas se necessário.
  ///
  /// Retorna mensagem de erro ou `null` se ok.
  Future<String?> redimensionarEAtualizarGrupoContasPagar({
    required String grupoParcelas,
    required String descricao,
    required double valorTotal,
    required DateTime primeiraDataVencimento,
    required int novaQuantidadeParcelas,
  }) async {
    if (novaQuantidadeParcelas <= 0) {
      return 'Informe uma quantidade de parcelas maior que zero.';
    }
    if (valorTotal <= 0) {
      return 'Valor total inválido.';
    }

    var parcelas = await getParcelasPorGrupo(grupoParcelas);
    if (parcelas.isEmpty) {
      return 'Grupo não encontrado.';
    }

    if (parcelas.length == 1) {
      final u = parcelas.first;
      if (u.parcelaNumero == null || u.parcelaTotal == null) {
        u.parcelaNumero = 1;
        u.parcelaTotal = u.parcelaTotal ?? 1;
        if (u.id != null) {
          await salvar(u);
        }
        parcelas = await getParcelasPorGrupo(grupoParcelas);
      }
    }

    parcelas.sort((a, b) {
      final pa = a.parcelaNumero ?? 0;
      final pb = b.parcelaNumero ?? 0;
      return pa.compareTo(pb);
    });

    final lancRepo = LancamentoRepository();

    if (novaQuantidadeParcelas < parcelas.length) {
      for (final p in parcelas) {
        final n = p.parcelaNumero ?? 0;
        if (n > novaQuantidadeParcelas && p.pago) {
          return 'Não é possível reduzir: a parcela $n já está paga.';
        }
      }
      for (final p in parcelas) {
        final n = p.parcelaNumero ?? 0;
        if (n > novaQuantidadeParcelas) {
          if (p.idLancamento != null) {
            await lancRepo.deletar(p.idLancamento!);
          } else if (p.id != null) {
            await deletar(p.id!);
          }
        }
      }
    }

    parcelas = await getParcelasPorGrupo(grupoParcelas);
    parcelas.sort((a, b) {
      final pa = a.parcelaNumero ?? 0;
      final pb = b.parcelaNumero ?? 0;
      return pa.compareTo(pb);
    });

    if (parcelas.any((p) => p.parcelaNumero == null)) {
      parcelas.sort((a, b) {
        final da = a.dataVencimento.millisecondsSinceEpoch;
        final db = b.dataVencimento.millisecondsSinceEpoch;
        return da.compareTo(db);
      });
      for (var i = 0; i < parcelas.length; i++) {
        final p = parcelas[i];
        if (p.parcelaNumero != null) continue;
        p.parcelaNumero = i + 1;
        p.parcelaTotal = p.parcelaTotal ?? parcelas.length;
        if (p.id != null) await salvar(p);
      }
      parcelas = await getParcelasPorGrupo(grupoParcelas);
      parcelas.sort((a, b) {
        final pa = a.parcelaNumero ?? 0;
        final pb = b.parcelaNumero ?? 0;
        return pa.compareTo(pb);
      });
    }

    final numerosPresentes = <int>{
      for (final p in parcelas)
        if (p.parcelaNumero != null) p.parcelaNumero!,
    };

    if (numerosPresentes.length != parcelas.length) {
      return 'Numeração de parcelas duplicada ou inválida neste grupo.';
    }

    for (var num = 1; num <= novaQuantidadeParcelas; num++) {
      if (numerosPresentes.contains(num)) continue;

      final venc = DateTime(
        primeiraDataVencimento.year,
        primeiraDataVencimento.month + num - 1,
        primeiraDataVencimento.day,
      );
      final ref = parcelas.isNotEmpty ? parcelas.first : null;
      final nova = ContaPagar(
        descricao: descricao,
        valor: 0,
        dataVencimento: venc,
        pago: false,
        dataPagamento: null,
        parcelaNumero: num,
        parcelaTotal: novaQuantidadeParcelas,
        grupoParcelas: grupoParcelas,
        formaPagamento: ref?.formaPagamento,
        idCartao: ref?.idCartao,
        idConta: ref?.idConta,
        dataCabecalho: ref?.dataCabecalho,
      );
      await salvar(nova);
    }

    parcelas = await getParcelasPorGrupo(grupoParcelas);
    if (parcelas.length != novaQuantidadeParcelas) {
      return 'Não foi possível ajustar para $novaQuantidadeParcelas parcelas.';
    }

    parcelas.sort((a, b) {
      final pa = a.parcelaNumero ?? 0;
      final pb = b.parcelaNumero ?? 0;
      return pa.compareTo(pb);
    });

    final n = parcelas.length;
    final valoresParcela = splitTotalEmPartesIguais(valorTotal, n);

    for (var i = 0; i < parcelas.length; i++) {
      final p = parcelas[i];
      final antes = ContaPagar.fromMap(p.toMap());
      final cab = p.dataCabecalho;
      final numParc = i + 1;
      final venc = DateTime(
        primeiraDataVencimento.year,
        primeiraDataVencimento.month + i,
        primeiraDataVencimento.day,
      );

      p.descricao = descricao;
      p.valor = valoresParcela[i];
      p.dataVencimento = venc;
      p.parcelaNumero = numParc;
      p.parcelaTotal = n;
      p.dataCabecalho = cab;
      await salvar(p);
      await sincronizarDataHoraLancamentoAposEditarConta(
        contaAtualizada: p,
        contaAntesEdicao: antes,
      );
    }

    return null;
  }

  /// Ajusta a data/hora do lançamento vinculado ao novo [ContaPagar.dataVencimento]
  /// (preservando hora/minuto/segundo do lançamento).
  ///
  /// [contaAntesEdicao] é usado só para localizar o lançamento quando o vínculo é
  /// implícito (mesmo `data_hora` antigo + valor + descrição).
  Future<void> sincronizarDataHoraLancamentoAposEditarConta({
    required ContaPagar contaAtualizada,
    ContaPagar? contaAntesEdicao,
  }) async {
    final lancRepo = LancamentoRepository();
    Lancamento? lanc;

    final idL = contaAtualizada.idLancamento;
    if (idL != null) {
      lanc = await lancRepo.getById(idL);
    }

    if (lanc == null && contaAtualizada.grupoParcelas.isNotEmpty) {
      final lista = await lancRepo.getParcelasPorGrupo(
        contaAtualizada.grupoParcelas,
      );
      final numParc = contaAtualizada.parcelaNumero ?? 1;
      for (final candidate in lista) {
        if ((candidate.parcelaNumero ?? 1) == numParc) {
          lanc = candidate;
          break;
        }
      }
    }

    if (lanc == null && contaAntesEdicao != null) {
      final db = await _db;
      final r = await db.query(
        'lancamentos',
        where: 'data_hora = ? AND valor = ? AND descricao = ?',
        whereArgs: [
          contaAntesEdicao.dataVencimento.millisecondsSinceEpoch,
          contaAntesEdicao.valor,
          contaAntesEdicao.descricao,
        ],
        limit: 1,
      );
      if (r.isNotEmpty) {
        lanc = Lancamento.fromMap(r.first);
      }
    }

    if (lanc?.id == null) return;

    final dh = lanc!.dataHora;
    final nova = DateTime(
      contaAtualizada.dataVencimento.year,
      contaAtualizada.dataVencimento.month,
      contaAtualizada.dataVencimento.day,
      dh.hour,
      dh.minute,
      dh.second,
      dh.millisecond,
      dh.microsecond,
    );

    if (nova.millisecondsSinceEpoch == dh.millisecondsSinceEpoch) return;

    await lancRepo.salvar(lanc.copyWith(dataHora: nova));

    // [LancamentoRepository.salvar] replica descricao/valor do lançamento na conta
    // vinculada; como o lançamento ainda pode ter texto/valor antigos após editar o
    // grupo no contas a pagar, regravamos a conta para manter o que o usuário salvou.
    await salvar(contaAtualizada);
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

  /// Contas com vencimento no dia civil [dia] (útil para vincular parcelas ao planejamento).
  Future<List<ContaPagar>> getPorVencimentoNoDia(DateTime dia) async {
    final db = await _db;
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));
    final result = await db.query(
      'conta_pagar',
      where: 'data_vencimento >= ? AND data_vencimento < ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'valor DESC, id ASC',
    );
    return result.map((e) => ContaPagar.fromMap(e)).toList();
  }

  Future<Map<int, ContaPagar>> getByIds(Set<int> ids) async {
    if (ids.isEmpty) return {};
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'conta_pagar',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
    return {
      for (final r in rows)
        if (r['id'] is int) (r['id'] as int): ContaPagar.fromMap(r),
    };
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

  /// Contas a pagar do cartão já ligadas a um lançamento, excluindo o grupo
  /// sintético da fatura (`FATURA_%`), **sem filtro de data** (associação à fatura importada).
  Future<List<ContaPagar>> listarParaAssociacaoFatura({
    required int idCartaoLocal,
  }) async {
    final db = await _db;

    final result = await db.query(
      'conta_pagar',
      where: '''
        id_cartao = ?
        AND id_lancamento IS NOT NULL
        AND grupo_parcelas NOT LIKE ?
      ''',
      whereArgs: [idCartaoLocal, 'FATURA_%'],
      orderBy: 'data_vencimento ASC',
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
