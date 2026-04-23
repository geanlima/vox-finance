import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/pessoa_me_deve.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class PessoaMeDeveRepository {
  final DbService _dbService;

  PessoaMeDeveRepository({DbService? dbService})
    : _dbService = dbService ?? DbService.instance;

  Future<Database> get _db async => _dbService.db;

  Future<PessoaMeDeve?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PessoaMeDeve.fromMap(rows.first);
  }

  Future<List<PessoaMeDeve>> listar() async {
    final db = await _db;
    final rows = await db.query(
      'pessoas_me_devem',
      orderBy: 'data_emprestimo DESC, id DESC',
    );
    return rows.map(PessoaMeDeve.fromMap).toList();
  }

  Future<double> totalPendente() async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_total - valor_recebido), 0) AS t
      FROM pessoas_me_devem
      WHERE (valor_total - valor_recebido) > 0.009
    ''');
    return (res.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<int> inserir({
    required String nome,
    required DateTime dataEmprestimo,
    required double valorTotal,
    String? observacao,
    bool compraCartao = false,
    int? idCartao,
    int? parcelasTotal,
    String? grupoReceitas,
  }) async {
    final db = await _db;
    final agora = DateTime.now().millisecondsSinceEpoch;
    final d = DateTime(dataEmprestimo.year, dataEmprestimo.month, dataEmprestimo.day);
    return db.insert('pessoas_me_devem', {
      'nome': nome.trim(),
      'data_emprestimo': d.millisecondsSinceEpoch,
      'valor_total': valorTotal,
      'valor_recebido': 0.0,
      'observacao': observacao?.trim().isEmpty == true ? null : observacao?.trim(),
      'compra_cartao': compraCartao ? 1 : 0,
      'id_cartao': idCartao,
      'parcelas_total': parcelasTotal,
      'grupo_receitas': grupoReceitas,
      'criado_em': agora,
    });
  }

  Future<void> atualizar(PessoaMeDeve p) async {
    final db = await _db;
    if (p.id == null) return;
    await db.transaction((txn) async {
      await txn.update(
        'pessoas_me_devem',
        {
          'nome': p.nome.trim(),
          'data_emprestimo': DateTime(
            p.dataEmprestimo.year,
            p.dataEmprestimo.month,
            p.dataEmprestimo.day,
          ).millisecondsSinceEpoch,
          'valor_total': p.valorTotal,
          'observacao':
              p.observacao?.trim().isEmpty == true ? null : p.observacao?.trim(),
          'compra_cartao': p.compraCartao ? 1 : 0,
          'id_cartao': p.idCartao,
          'parcelas_total': p.parcelasTotal,
          'grupo_receitas': p.grupoReceitas,
        },
        where: 'id = ?',
        whereArgs: [p.id],
      );

      final grupo = p.grupoReceitas?.trim();
      final parcelasTotal = p.parcelasTotal ?? 0;
      if (grupo != null && grupo.isNotEmpty && parcelasTotal > 1) {
        await _sincronizarLancamentosGrupoReceitas(
          txn: txn,
          pessoa: p,
          grupo: grupo,
        );
      }
    });
  }

  DateTime _clampDay(int ano, int mes, int dia) {
    final last = DateTime(ano, mes + 1, 0).day;
    final d = dia.clamp(1, last);
    return DateTime(ano, mes, d);
  }

  String _descricaoParcela({
    required PessoaMeDeve pessoa,
    required int parcelaNumero,
    required int parcelaTotal,
  }) {
    final obs = pessoa.observacao?.trim();
    final nome = pessoa.nome.trim();
    if (obs != null && obs.isNotEmpty) {
      return 'Parcela $parcelaNumero/$parcelaTotal — $nome — $obs';
    }
    return 'Parcela $parcelaNumero/$parcelaTotal — $nome';
  }

  Future<void> _sincronizarLancamentosGrupoReceitas({
    required Transaction txn,
    required PessoaMeDeve pessoa,
    required String grupo,
  }) async {
    final parcelasTotal = pessoa.parcelasTotal ?? 0;
    if (parcelasTotal <= 1) return;

    final rows = await txn.query(
      'lancamentos',
      where: 'grupo_parcelas = ? AND tipo_movimento = ?',
      whereArgs: [grupo, 0], // receita
      orderBy: 'parcela_numero ASC, data_hora ASC',
    );
    if (rows.isEmpty) return;

    final lancs = rows.map((e) => Lancamento.fromMap(e)).toList();
    final pagos = lancs.where((l) => l.pago).toList();
    final pendentes = lancs.where((l) => !l.pago).toList();

    final pagosCount = pagos.length;
    final totalRecebido = pagos.fold<double>(0.0, (s, l) => s + l.valor);
    final restante = (pessoa.valorTotal - totalRecebido).clamp(0.0, pessoa.valorTotal);
    final pendCountAlvo = (parcelasTotal - pagosCount).clamp(0, parcelasTotal);

    // Atualiza descrições e parcela_total em todos (pagos e pendentes).
    for (final l in lancs) {
      if (l.id == null) continue;
      final num = l.parcelaNumero ?? 1;
      await txn.update(
        'lancamentos',
        {
          'descricao': _descricaoParcela(
            pessoa: pessoa,
            parcelaNumero: num,
            parcelaTotal: parcelasTotal,
          ),
          'parcela_total': parcelasTotal,
        },
        where: 'id = ?',
        whereArgs: [l.id],
      );
    }

    // Se já existem parcelas pagas, não mexemos nelas além da descrição.
    // Recalcula apenas as parcelas pendentes a partir da data base (dataEmprestimo = 1ª parcela).
    final base = DateTime(
      pessoa.dataEmprestimo.year,
      pessoa.dataEmprestimo.month,
      pessoa.dataEmprestimo.day,
    );

    // Ajusta quantidade de pendentes no grupo (deleta sobras).
    if (pendentes.length > pendCountAlvo) {
      final sobras = pendentes.sublist(pendCountAlvo);
      for (final l in sobras) {
        if (l.id == null) continue;
        await txn.delete('lancamentos', where: 'id = ?', whereArgs: [l.id]);
      }
    }

    // Garante lista de pendentes com tamanho alvo.
    final pendentesAtuais =
        pendentes.length > pendCountAlvo ? pendentes.sublist(0, pendCountAlvo) : pendentes;

    // Se faltam pendentes, insere novas.
    if (pendentesAtuais.length < pendCountAlvo) {
      final faltam = pendCountAlvo - pendentesAtuais.length;
      for (int i = 0; i < faltam; i++) {
        final num = pagosCount + pendentesAtuais.length + i + 1;
        final ref = DateTime(base.year, base.month + (num - 1), 1);
        final data = _clampDay(ref.year, ref.month, base.day);
        final lanc = Lancamento(
          valor: 0.0,
          descricao: _descricaoParcela(
            pessoa: pessoa,
            parcelaNumero: num,
            parcelaTotal: parcelasTotal,
          ),
          formaPagamento: FormaPagamento.pix,
          dataHora: data,
          pagamentoFatura: false,
          pago: false,
          dataPagamento: null,
          categoria: Categoria.financasPessoais,
          tipoMovimento: TipoMovimento.receita,
          idConta: null,
          grupoParcelas: grupo,
          parcelaNumero: num,
          parcelaTotal: parcelasTotal,
        );
        await txn.insert('lancamentos', lanc.toMap()..remove('id'));
      }
    }

    // Recarrega pendentes (após inserts/deletes) para recalcular valores/datas.
    final pendRows2 = await txn.query(
      'lancamentos',
      where: 'grupo_parcelas = ? AND tipo_movimento = ? AND pago = 0',
      whereArgs: [grupo, 0],
      orderBy: 'parcela_numero ASC, data_hora ASC',
    );
    final pend2 = pendRows2.map((e) => Lancamento.fromMap(e)).toList();
    if (pend2.isEmpty) return;

    // Recalcula valores das pendentes para fechar no "restante".
    final baseVal = restante / pend2.length;
    final valorBase = double.parse(baseVal.toStringAsFixed(2));
    final totalBase = valorBase * pend2.length;
    final ajusteUltima =
        double.parse((restante - totalBase).toStringAsFixed(2));

    for (int i = 0; i < pend2.length; i++) {
      final l = pend2[i];
      if (l.id == null) continue;
      final num = l.parcelaNumero ?? (pagosCount + i + 1);
      final ref = DateTime(base.year, base.month + (num - 1), 1);
      final data = _clampDay(ref.year, ref.month, base.day);
      final valorParcela =
          (i == pend2.length - 1)
              ? double.parse((valorBase + ajusteUltima).toStringAsFixed(2))
              : valorBase;

      await txn.update(
        'lancamentos',
        {
          'valor': valorParcela,
          'data_hora': data.millisecondsSinceEpoch,
          'descricao': _descricaoParcela(
            pessoa: pessoa,
            parcelaNumero: num,
            parcelaTotal: parcelasTotal,
          ),
          'parcela_numero': num,
          'parcela_total': parcelasTotal,
        },
        where: 'id = ?',
        whereArgs: [l.id],
      );
    }
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    final rows = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final grupo = rows.isEmpty ? null : (rows.first['grupo_receitas'] as String?);

    await db.transaction((txn) async {
      if (grupo != null && grupo.trim().isNotEmpty) {
        await txn.delete(
          'lancamentos',
          where: 'grupo_parcelas LIKE ?',
          whereArgs: ['${grupo.trim()}%'],
        );
      }
      await txn.delete('pessoas_me_devem', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Gera lançamentos de RECEITA parcelados (futuros) para uma compra no cartão.
  /// Os lançamentos ficam com pago=false e vinculados por [grupoParcelas].
  Future<void> gerarReceitasParceladasCompraCartao({
    required String nomePessoa,
    required String? observacao,
    required double valorTotal,
    required DateTime dataCompra,
    required int parcelasTotal,
    required int diaFechamento,
    required int diaVencimento,
    required String grupoParcelas,
  }) async {
    if (parcelasTotal <= 1) return;
    if (valorTotal <= 0) return;

    DateTime clampDay(int ano, int mes, int dia) {
      final last = DateTime(ano, mes + 1, 0).day;
      final d = dia.clamp(1, last);
      return DateTime(ano, mes, d);
    }

    // Regra igual à fatura: compra até o fechamento (inclusive) vence no mesmo mês,
    // após o fechamento vence no mês seguinte.
    final compra = DateTime(dataCompra.year, dataCompra.month, dataCompra.day);
    final diaFech =
        diaFechamento.clamp(1, DateTime(compra.year, compra.month + 1, 0).day);
    var ano = compra.year;
    var mes = (compra.day <= diaFech) ? compra.month : (compra.month + 1);
    while (mes > 12) {
      mes -= 12;
      ano += 1;
    }
    final primeiraData = clampDay(ano, mes, diaVencimento);

    // Parcelas: ajusta última para fechar centavos.
    final base = (valorTotal / parcelasTotal);
    final valorBase = double.parse(base.toStringAsFixed(2));
    final totalBase = valorBase * parcelasTotal;
    final ajusteUltima = double.parse((valorTotal - totalBase).toStringAsFixed(2));

    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 1; i <= parcelasTotal; i++) {
        final refMes = DateTime(primeiraData.year, primeiraData.month + (i - 1), 1);
        final dataVenc = clampDay(refMes.year, refMes.month, diaVencimento);
        final valorParcela =
            (i == parcelasTotal)
                ? double.parse((valorBase + ajusteUltima).toStringAsFixed(2))
                : valorBase;

        final descBase =
            (observacao != null && observacao.trim().isNotEmpty)
                ? 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()} — ${observacao.trim()}'
                : 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()}';

        final lanc = Lancamento(
          valor: valorParcela,
          descricao: descBase,
          formaPagamento: FormaPagamento.pix, // recebimento previsto
          dataHora: dataVenc,
          pagamentoFatura: false,
          pago: false,
          dataPagamento: null,
          categoria: Categoria.financasPessoais,
          tipoMovimento: TipoMovimento.receita,
          idCartao: null,
          idConta: null,
          grupoParcelas: grupoParcelas,
          parcelaNumero: i,
          parcelaTotal: parcelasTotal,
        );

        final map = lanc.toMap()..remove('id');
        await txn.insert(
          'lancamentos',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Gera lançamentos de RECEITA parcelados (futuros) a partir de uma data escolhida pelo usuário.
  /// A 1ª parcela cai exatamente em [dataPrimeiraParcela] (com clamp de dia no mês, se necessário).
  Future<void> gerarReceitasParceladasAPartirDaData({
    required String nomePessoa,
    required String? observacao,
    required double valorTotal,
    required DateTime dataPrimeiraParcela,
    required int parcelasTotal,
    required FormaPagamento formaPagamento,
    required String grupoParcelas,
  }) async {
    if (parcelasTotal <= 1) return;
    if (valorTotal <= 0) return;

    DateTime clampDay(int ano, int mes, int dia) {
      final last = DateTime(ano, mes + 1, 0).day;
      final d = dia.clamp(1, last);
      return DateTime(ano, mes, d);
    }

    final dt0 = DateTime(
      dataPrimeiraParcela.year,
      dataPrimeiraParcela.month,
      dataPrimeiraParcela.day,
    );

    final base = (valorTotal / parcelasTotal);
    final valorBase = double.parse(base.toStringAsFixed(2));
    final totalBase = valorBase * parcelasTotal;
    final ajusteUltima = double.parse((valorTotal - totalBase).toStringAsFixed(2));

    final obsTxt =
        (observacao != null && observacao.trim().isNotEmpty) ? observacao.trim() : null;
    final db = await _db;

    await db.transaction((txn) async {
      for (var i = 1; i <= parcelasTotal; i++) {
        final refMes = DateTime(dt0.year, dt0.month + (i - 1), 1);
        final data = clampDay(refMes.year, refMes.month, dt0.day);
        final valorParcela =
            (i == parcelasTotal)
                ? double.parse((valorBase + ajusteUltima).toStringAsFixed(2))
                : valorBase;

        final descBase =
            obsTxt != null
                ? 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()} — $obsTxt'
                : 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()}';

        final lanc = Lancamento(
          valor: valorParcela,
          descricao: descBase,
          formaPagamento: formaPagamento,
          dataHora: data,
          pagamentoFatura: false,
          pago: false,
          dataPagamento: null,
          categoria: Categoria.financasPessoais,
          tipoMovimento: TipoMovimento.receita,
          idCartao: null,
          idConta: null,
          grupoParcelas: grupoParcelas,
          parcelaNumero: i,
          parcelaTotal: parcelasTotal,
        );

        final map = lanc.toMap()..remove('id');
        await txn.insert(
          'lancamentos',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Gera lançamentos de DESPESA na data da compra/parcela (quitados no lançamento),
  /// com conta a pagar vinculada no vencimento do cartão (em aberto) para controle.
  Future<void> gerarDespesasParceladasNoVencimentoCartao({
    required String nomePessoa,
    required String? observacao,
    required double valorTotal,
    required DateTime dataCompra,
    required int parcelasTotal,
    required int idCartao,
    required int diaFechamento,
    required int diaVencimento,
    required String grupoParcelasPrefixo,
  }) async {
    if (parcelasTotal <= 1) return;
    if (valorTotal <= 0) return;

    DateTime clampDay(int ano, int mes, int dia) {
      final last = DateTime(ano, mes + 1, 0).day;
      final d = dia.clamp(1, last);
      return DateTime(ano, mes, d);
    }

    final compra = DateTime(dataCompra.year, dataCompra.month, dataCompra.day);
    final fechamentoEsteMes = clampDay(compra.year, compra.month, diaFechamento);
    final aposFechamento = compra.isAfter(fechamentoEsteMes);
    final baseOffsetMes = aposFechamento ? 2 : 1;

    // Parcelas: ajusta última para fechar centavos.
    final base = (valorTotal / parcelasTotal);
    final valorBase = double.parse(base.toStringAsFixed(2));
    final totalBase = valorBase * parcelasTotal;
    final ajusteUltima = double.parse((valorTotal - totalBase).toStringAsFixed(2));

    final grupo = '${grupoParcelasPrefixo}_DESP';

    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 1; i <= parcelasTotal; i++) {
        // LANÇAMENTO (despesa): data da compra/parcela (compra + (i-1) meses)
        final refLanc = DateTime(compra.year, compra.month + (i - 1), 1);
        final dataLanc = clampDay(refLanc.year, refLanc.month, compra.day);

        // CONTA A PAGAR: vencimento do cartão (mês da compra + offset (1 ou 2) + (i-1))
        final refVenc = DateTime(
          compra.year,
          compra.month + baseOffsetMes + (i - 1),
          1,
        );
        final dataVenc = clampDay(refVenc.year, refVenc.month, diaVencimento);

        final valorParcela =
            (i == parcelasTotal)
                ? double.parse((valorBase + ajusteUltima).toStringAsFixed(2))
                : valorBase;

        final desc =
            (observacao != null && observacao.trim().isNotEmpty)
                ? 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()} — ${observacao.trim()}'
                : 'Parcela $i/$parcelasTotal — ${nomePessoa.trim()}';

        // Lançamento DESPESA quitado na data da parcela (compra já entrou no cartão).
        final lanc = Lancamento(
          valor: valorParcela,
          descricao: 'A pagar (cartão): $desc',
          formaPagamento: FormaPagamento.credito,
          dataHora: dataLanc,
          pagamentoFatura: false,
          pago: true,
          dataPagamento: dataLanc,
          categoria: Categoria.financasPessoais,
          tipoMovimento: TipoMovimento.despesa,
          idCartao: idCartao,
          idConta: null,
          grupoParcelas: grupo,
          parcelaNumero: i,
          parcelaTotal: parcelasTotal,
        );

        final map = lanc.toMap()..remove('id');
        final idLanc = await txn.insert('lancamentos', map, conflictAlgorithm: ConflictAlgorithm.replace);

        // Conta a pagar vinculada
        await txn.insert(
          'conta_pagar',
          {
            'descricao': lanc.descricao,
            'valor': valorParcela,
            'data_vencimento': dataVenc.millisecondsSinceEpoch,
            'pago': 0,
            'data_pagamento': null,
            'parcela_numero': i,
            'parcela_total': parcelasTotal,
            'grupo_parcelas': grupo,
            'forma_pagamento': lanc.formaPagamento.index,
            'id_cartao': idCartao,
            'id_conta': null,
            'id_lancamento': idLanc,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Registra recebimento parcial ou total: grava [Lancamento] como receita (pago)
  /// e atualiza [valor_recebido].
  Future<void> registrarRecebimentoComLancamento({
    required int idPessoa,
    required double valor,
    required DateTime dataRecebimento,
    required FormaPagamento formaPagamento,
    int? idConta,
  }) async {
    if (valor <= 0) return;
    final db = await _db;

    final rows = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [idPessoa],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final p = PessoaMeDeve.fromMap(rows.first);
    final pendente = p.valorPendente;
    if (pendente <= 0) return;

    final creditar = valor > pendente ? pendente : valor;

    final dtPag = DateTime(
      dataRecebimento.year,
      dataRecebimento.month,
      dataRecebimento.day,
    );

    final obs = p.observacao;
    final desc =
        obs != null && obs.isNotEmpty
            ? 'Recebimento: ${p.nome} — $obs'
            : 'Recebimento: ${p.nome}';

    await db.transaction((txn) async {
      final lanc = Lancamento(
        valor: creditar,
        descricao: desc,
        formaPagamento: formaPagamento,
        dataHora: dtPag,
        pagamentoFatura: false,
        pago: true,
        dataPagamento: dtPag,
        categoria: Categoria.financasPessoais,
        tipoMovimento: TipoMovimento.receita,
        idConta: idConta,
      );

      final map = lanc.toMap()..remove('id');
      await txn.insert(
        'lancamentos',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final novo = p.valorRecebido + creditar;
      await txn.update(
        'pessoas_me_devem',
        {'valor_recebido': novo},
        where: 'id = ?',
        whereArgs: [idPessoa],
      );
    });
  }

  /// Registra recebimento parcelado: cria N lançamentos de receita PENDENTES (pago=false).
  /// Não altera [valor_recebido] aqui; ele só sobe quando você marcar o recebimento.
  ///
  /// - [parcelasTotal] >= 1
  /// - Se [valorInformadoEhTotal] = true, [valorInformado] representa o total do recebimento.
  ///   Caso contrário, representa o valor por parcela.
  ///
  /// Datas: parcela 1 na data informada; demais parcelas mês a mês (mesma lógica de "parcelas").
  Future<String?> registrarRecebimentoParceladoComLancamentos({
    required int idPessoa,
    required double valorInformado,
    required bool valorInformadoEhTotal,
    required int parcelasTotal,
    required DateTime dataPrimeiraParcela,
    required FormaPagamento formaPagamento,
    int? idConta,
  }) async {
    if (valorInformado <= 0) return null;
    if (parcelasTotal < 1) return null;

    final db = await _db;
    final rows = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [idPessoa],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final p = PessoaMeDeve.fromMap(rows.first);
    final pendente = p.valorPendente;
    if (pendente <= 0) return null;

    // Total a creditar: não pode ultrapassar o pendente.
    final totalDesejado =
        valorInformadoEhTotal ? valorInformado : (valorInformado * parcelasTotal);
    final totalCreditar = totalDesejado > pendente ? pendente : totalDesejado;

    // Calcula parcelas, ajustando a última para fechar centavos e/ou corte por pendente.
    final base = totalCreditar / parcelasTotal;
    final valorBase = double.parse(base.toStringAsFixed(2));
    final totalBase = valorBase * parcelasTotal;
    final ajusteUltima =
        double.parse((totalCreditar - totalBase).toStringAsFixed(2));

    final dt0 = DateTime(
      dataPrimeiraParcela.year,
      dataPrimeiraParcela.month,
      dataPrimeiraParcela.day,
    );

    DateTime clampDay(int ano, int mes, int dia) {
      final last = DateTime(ano, mes + 1, 0).day;
      final d = dia.clamp(1, last);
      return DateTime(ano, mes, d);
    }

    final obs = p.observacao;
    final descBase =
        obs != null && obs.trim().isNotEmpty
            ? 'Recebimento: ${p.nome} — ${obs.trim()}'
            : 'Recebimento: ${p.nome}';

    final grupo = 'PMD_REC_${idPessoa}_${DateTime.now().millisecondsSinceEpoch}';

    await db.transaction((txn) async {
      for (var i = 1; i <= parcelasTotal; i++) {
        final ref = DateTime(dt0.year, dt0.month + (i - 1), 1);
        final dataParcela = clampDay(ref.year, ref.month, dt0.day);
        final valorParcela =
            (i == parcelasTotal)
                ? double.parse((valorBase + ajusteUltima).toStringAsFixed(2))
                : valorBase;
        if (valorParcela <= 0) continue;

        final lanc = Lancamento(
          valor: valorParcela,
          descricao:
              parcelasTotal > 1 ? 'Parcela $i/$parcelasTotal — $descBase' : descBase,
          formaPagamento: formaPagamento,
          dataHora: dataParcela,
          pagamentoFatura: false,
          pago: false,
          dataPagamento: null,
          categoria: Categoria.financasPessoais,
          tipoMovimento: TipoMovimento.receita,
          idConta: idConta,
          grupoParcelas: grupo,
          parcelaNumero: parcelasTotal > 1 ? i : null,
          parcelaTotal: parcelasTotal > 1 ? parcelasTotal : null,
        );

        final map = lanc.toMap()..remove('id');
        await txn.insert(
          'lancamentos',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.update(
        'pessoas_me_devem',
        {
          // mantém valor_recebido como está; recebimento é registrado ao marcar parcelas como pagas
          'grupo_receitas': grupo,
        },
        where: 'id = ?',
        whereArgs: [idPessoa],
      );
    });

    return grupo;
  }

  Future<List<Lancamento>> listarReceitasPendentesPorGrupo(String grupo) async {
    final db = await _db;
    final rows = await db.query(
      'lancamentos',
      where: 'grupo_parcelas = ? AND pago = 0 AND tipo_movimento = ?',
      whereArgs: [grupo, 0], // 0 = receita (TipoMovimento.receita)
      orderBy: 'data_hora ASC',
    );
    return rows.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<void> marcarReceitaParcelaComoRecebida({
    required int idPessoa,
    required int idLancamento,
    required FormaPagamento formaPagamento,
    required DateTime dataRecebimento,
    int? idConta,
  }) async {
    final db = await _db;
    final rowsP = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [idPessoa],
      limit: 1,
    );
    if (rowsP.isEmpty) return;
    final p = PessoaMeDeve.fromMap(rowsP.first);

    final rowsL = await db.query(
      'lancamentos',
      where: 'id = ?',
      whereArgs: [idLancamento],
      limit: 1,
    );
    if (rowsL.isEmpty) return;
    final l = Lancamento.fromMap(rowsL.first);
    if (l.pago) return;

    final dtPag = DateTime(
      dataRecebimento.year,
      dataRecebimento.month,
      dataRecebimento.day,
    );

    await db.transaction((txn) async {
      await txn.update(
        'lancamentos',
        {
          'pago': 1,
          'data_pagamento': dtPag.millisecondsSinceEpoch,
          'forma_pagamento': formaPagamento.index,
          'id_conta': idConta,
        },
        where: 'id = ?',
        whereArgs: [idLancamento],
      );

      final novo = p.valorRecebido + l.valor;
      await txn.update(
        'pessoas_me_devem',
        {'valor_recebido': novo},
        where: 'id = ?',
        whereArgs: [idPessoa],
      );
    });
  }
}
