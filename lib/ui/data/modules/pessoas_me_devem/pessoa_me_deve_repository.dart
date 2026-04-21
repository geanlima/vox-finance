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
    await db.update(
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
}
