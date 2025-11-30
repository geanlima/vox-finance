import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class CartaoCreditoRepository {
  final DbService _dbService;

  CartaoCreditoRepository({DbService? dbService})
    : _dbService = dbService ?? DbService();

  // ============================================================
  //  G E R A R   F A T U R A   D O   C A R T Ã O   (FECHAMENTO)
  // ============================================================

  Future<void> gerarFaturaDoCartao(int idCartao, {DateTime? referencia}) async {
    final database = await _dbService.db;
    final hoje = referencia ?? DateTime.now();

    final res = await database.query(
      'cartao_credito',
      where: 'id = ?',
      whereArgs: [idCartao],
      limit: 1,
    );
    if (res.isEmpty) return;

    final cartao = CartaoCredito.fromMap(res.first);

    final bool ehCreditoLike =
        cartao.tipo == TipoCartao.credito || cartao.tipo == TipoCartao.ambos;

    if (!ehCreditoLike) return;
    if (!cartao.controlaFatura) return;
    if (cartao.diaFechamento == null || cartao.diaVencimento == null) return;

    final int diaFechamento = cartao.diaFechamento!;
    final int diaVencimento = cartao.diaVencimento!;

    int anoAtual = hoje.year;
    int mesAtual = hoje.month;

    int mesAnterior = mesAtual - 1;
    int anoAnterior = anoAtual;
    if (mesAnterior == 0) {
      mesAnterior = 12;
      anoAnterior--;
    }

    final inicioPeriodo = DateTime(anoAnterior, mesAnterior, diaFechamento + 1);
    final fimPeriodo = DateTime(
      anoAtual,
      mesAtual,
      diaFechamento,
      23,
      59,
      59,
      999,
    );

    final inicioMs = inicioPeriodo.millisecondsSinceEpoch;
    final fimMs = fimPeriodo.millisecondsSinceEpoch;

    final compras = await database.query(
      'lancamentos',
      where:
          'id_cartao = ? AND forma_pagamento = ? AND pagamento_fatura = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [idCartao, FormaPagamento.credito.index, inicioMs, fimMs],
    );

    if (compras.isEmpty) return;

    final total = compras.fold<double>(
      0.0,
      (acc, row) => acc + (row['valor'] as num).toDouble(),
    );

    if (total <= 0) return;

    final dataVencimento = DateTime(anoAtual, mesAtual, diaVencimento);
    final dataVencimentoMs = dataVencimento.millisecondsSinceEpoch;

    // 🔹 Se já existir fatura para esse vencimento, atualiza e garante que fique PENDENTE
    final faturaExistente = await database.query(
      'lancamentos',
      where: 'id_cartao = ? AND pagamento_fatura = 1 AND data_hora = ?',
      whereArgs: [idCartao, dataVencimentoMs],
      limit: 1,
    );

    if (faturaExistente.isNotEmpty) {
      final idFatura = faturaExistente.first['id'] as int;
      await database.update(
        'lancamentos',
        {
          'valor': total,
          'pago': 0, // ← volta a ser pendente
          'data_pagamento': null, // ← limpa data de pagamento
        },
        where: 'id = ?',
        whereArgs: [idFatura],
      );
      return;
    }

    // 🔹 Se não existir, cria a fatura já como pendente
    final primeiraCompra = Lancamento.fromMap(compras.first);

    final descricaoFatura =
        'Fatura ${cartao.descricao} ${mesAtual.toString().padLeft(2, '0')}/$anoAtual';

    final lancFatura = Lancamento(
      valor: total,
      descricao: descricaoFatura,
      formaPagamento: FormaPagamento.credito,
      dataHora: dataVencimento,
      pagamentoFatura: true,
      categoria: primeiraCompra.categoria,
      pago: false,
      dataPagamento: null,
      idCartao: idCartao,
    );

    final dados = lancFatura.toMap();
    // Garantindo explicitamente que nasce pendente
    dados['pago'] = 0;
    dados['data_pagamento'] = null;

    await database.insert('lancamentos', dados);
  }

  // ============================================================
  //  CRUD  C A R T Õ E S   D E   C R É D I T O
  // ============================================================

  Future<int> salvarCartaoCredito(CartaoCredito cartao) async {
    final database = await _dbService.db;

    try {
      if (cartao.id == null) {
        final id = await database.insert(
          'cartao_credito',
          cartao.toMapInsert(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        cartao.id = id;
        return id;
      } else {
        return await database.update(
          'cartao_credito',
          cartao.toMapUpdate(),
          where: 'id = ?',
          whereArgs: [cartao.id],
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<CartaoCredito>> getCartoesCredito() async {
    final database = await _dbService.db;
    try {
      final result = await database.query(
        'cartao_credito',
        orderBy: 'descricao ASC',
      );
      return result.map((e) => CartaoCredito.fromMap(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<CartaoCredito?> getCartaoCreditoById(int id) async {
    final database = await _dbService.db;
    try {
      final result = await database.query(
        'cartao_credito',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return CartaoCredito.fromMap(result.first);
    } catch (e) {
      return null;
    }
  }

  Future<void> deletarCartaoCredito(int id) async {
    final database = await _dbService.db;
    await database.delete('cartao_credito', where: 'id = ?', whereArgs: [id]);
  }
}
