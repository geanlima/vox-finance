// lib/ui/data/modules/lancamentos/lancamento_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/renda_mensal_resumo.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';

class TotaisDia {
  final double totalDespesas;
  final double totalReceitas;

  TotaisDia({required this.totalDespesas, required this.totalReceitas});
}

class LancamentoRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  // 🔒 PADRÃO DO BANCO (AJUSTE SE PRECISAR)
  static const int tipoDespesaDb = 1;
  static const int tipoReceitaDb = 2;

  // ----------------- Helpers -----------------

  double _toDouble(Object? v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ----------------- CRUD -----------------

  Future<void> deletarPorGrupo(String grupoParcelas) async {
    final db = await _db;
    await db.delete(
      'lancamentos',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupoParcelas],
    );
  }

  Future<Lancamento?> getById(int id) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Lancamento.fromMap(result.first);
  }

  Future<int> salvar(Lancamento lanc) async {
    final db = await _db;

    if (lanc.id == null) {
      final dados = lanc.toMap()..remove('id');
      final id = await db.insert(
        'lancamentos',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      lanc.id = id;
      return id;
    } else {
      return db.update(
        'lancamentos',
        lanc.toMap(),
        where: 'id = ?',
        whereArgs: [lanc.id],
      );
    }
  }

  Future<void> deletar(int id) async {
    final db = await _db;

    // 1) Apaga a parcela de contas a pagar vinculada a este lançamento
    await db.delete('conta_pagar', where: 'id_lancamento = ?', whereArgs: [id]);

    // 2) Apaga o lançamento em si
    await db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

  // ----------------- Consultas por data -----------------

  Future<TotaisDia> getTotaisPorDia(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN tipo_movimento = ? THEN valor ELSE 0 END) AS total_despesas,
        SUM(CASE WHEN tipo_movimento = ? THEN valor ELSE 0 END) AS total_receitas
      FROM lancamentos
      WHERE data_hora >= ? AND data_hora < ?
      ''',
      [
        tipoDespesaDb,
        tipoReceitaDb,
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
      ],
    );

    final row = result.isNotEmpty ? result.first : <String, Object?>{};

    return TotaisDia(
      totalDespesas: _toDouble(row['total_despesas']),
      totalReceitas: _toDouble(row['total_receitas']),
    );
  }

  Future<List<Lancamento>> getByDay(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora < ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora DESC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<List<Lancamento>> getByPeriodo(DateTime inicio, DateTime fim) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'data_hora >= ? AND data_hora <= ?',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  // ----------------- Futuro -----------------

  Future<List<Lancamento>> getFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'data_hora > ? AND data_hora <= ?',
      whereArgs: [
        DateTime.now().millisecondsSinceEpoch,
        dataLimite.millisecondsSinceEpoch,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((map) => Lancamento.fromMap(map)).toList();
  }

  Future<List<Lancamento>> getDespesasByPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? AND data_hora <= ?
      AND tipo_movimento = ?
    ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoDespesaDb,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<List<Lancamento>> getDespesasByDay(DateTime dia) async {
    final db = await _db;

    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    final result = await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? AND data_hora < ?
      AND tipo_movimento = ?
    ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoDespesaDb,
      ],
      orderBy: 'data_hora DESC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<double> getTotalFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT SUM(valor) AS total
      FROM lancamentos
      WHERE data_hora > ? AND data_hora <= ?
      ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        dataLimite.millisecondsSinceEpoch,
      ],
    );

    return _toDouble(result.first['total']);
  }

  // ----------------- Pago -----------------

  Future<void> marcarComoPago(int id, bool pago) async {
    final db = await _db;

    await db.update(
      'lancamentos',
      {
        'pago': pago ? 1 : 0,
        'data_pagamento': pago ? DateTime.now().millisecondsSinceEpoch : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ----------------- Parcelas -----------------

  Future<List<Lancamento>> getParcelasPorGrupo(String grupo) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }

  Future<void> salvarParceladosFuturos(
    Lancamento base,
    int qtdParcelas, {
    CartaoCredito? cartao,
  }) async {
    final db = await _db;

    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataCompra = base.dataHora;

    // ⭐ Buscar diaVencimento do cartão (para contas a pagar)
    int? diaVencimentoCartao = cartao?.diaVencimento;
    if (diaVencimentoCartao == null && base.idCartao != null) {
      final cartaoRepo = CartaoCreditoRepository();
      final cartaoDb = await cartaoRepo.getCartaoCreditoById(base.idCartao!);
      diaVencimentoCartao = cartaoDb?.diaVencimento;
    }

    // ✅ Melhor prática: transação (evita salvar metade se der erro)
    await db.transaction((txn) async {
      for (int i = 0; i < qtdParcelas; i++) {
        final numeroParcela = i + 1;

        // LANÇAMENTO: data compra + (n-1) meses
        DateTime dataLancamento = _calcularDataLancamento(
          dataCompra: dataCompra,
          numeroParcela: numeroParcela,
        );

        // CONTA A PAGAR: vencimento no dia do cartão
        DateTime dataVencimentoConta;
        if (diaVencimentoCartao != null) {
          dataVencimentoConta = _calcularVencimentoCartaoParaConta(
            dataCompra: dataCompra,
            diaVencimento: diaVencimentoCartao,
            numeroParcela: numeroParcela,
          );

          dataVencimentoConta = _garantirDataValida(
            dataVencimentoConta.year,
            dataVencimentoConta.month,
            dataVencimentoConta.day,
          );
        } else {
          dataVencimentoConta = dataCompra.add(
            Duration(days: 30 * numeroParcela),
          );
        }

        // 1) Lancamento
        final bool pagoParcela = base.pago; // vem da tela
        final DateTime? dataPg =
            pagoParcela ? (base.dataPagamento ?? DateTime.now()) : null;

        final lancParcela = base.copyWith(
          id: null,
          valor: valorParcela,
          dataHora: dataLancamento,
          grupoParcelas: grupo,
          parcelaNumero: numeroParcela,
          parcelaTotal: qtdParcelas,
          pago: pagoParcela,
          dataPagamento: dataPg,
        );

        final dadosLanc = lancParcela.toMap()..remove('id');
        final int idLancamento = await txn.insert('lancamentos', dadosLanc);

        // 2) conta a pagar
        final conta = ContaPagar(
          id: null,
          descricao: lancParcela.descricao,
          valor: valorParcela,
          dataVencimento: dataVencimentoConta,
          pago: false,
          dataPagamento: null,
          parcelaNumero: numeroParcela,
          parcelaTotal: qtdParcelas,
          grupoParcelas: grupo,
          idLancamento: idLancamento,
          formaPagamento: FormaPagamento.credito,
          idCartao: base.idCartao,
        );

        final dadosConta = conta.toMap()..remove('id');
        await txn.insert('conta_pagar', dadosConta);
      }
    });
  }

  DateTime _calcularVencimentoCartaoParaConta({
    required DateTime dataCompra,
    required int diaVencimento,
    required int numeroParcela,
  }) {
    final dia = diaVencimento.clamp(1, 28);

    final vencimentoEsteMes = DateTime(dataCompra.year, dataCompra.month, dia);

    if (dataCompra.isBefore(vencimentoEsteMes)) {
      return DateTime(
        dataCompra.year,
        dataCompra.month + (numeroParcela - 1),
        dia,
      );
    } else {
      return DateTime(dataCompra.year, dataCompra.month + numeroParcela, dia);
    }
  }

  DateTime _calcularDataLancamento({
    required DateTime dataCompra,
    required int numeroParcela,
  }) {
    if (numeroParcela == 1) return dataCompra;

    return DateTime(
      dataCompra.year,
      dataCompra.month + (numeroParcela - 1),
      dataCompra.day,
      dataCompra.hour,
      dataCompra.minute,
      dataCompra.second,
      dataCompra.millisecond,
    );
  }

  DateTime _garantirDataValida(int ano, int mes, int dia) {
    while (mes > 12) {
      mes -= 12;
      ano += 1;
    }

    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    final diaAjustado = dia.clamp(1, ultimoDia);

    return DateTime(ano, mes, diaAjustado);
  }

  // -------------------------------------------------
  // RESUMO MENSAL DE RECEITAS (Minha Renda)
  // -------------------------------------------------

  Future<List<RendaMensalResumo>> getResumoRendaMensal() async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT
        CAST(strftime('%Y', datetime(data_hora/1000, 'unixepoch')) AS INTEGER) AS ano,
        CAST(strftime('%m', datetime(data_hora/1000, 'unixepoch')) AS INTEGER) AS mes,
        SUM(valor) AS total
      FROM lancamentos
      WHERE tipo_movimento = ?
      GROUP BY ano, mes
      ORDER BY ano DESC, mes DESC;
      ''',
      [tipoReceitaDb],
    );

    return result.map((row) {
      return RendaMensalResumo(
        ano: (row['ano'] as num).toInt(),
        mes: (row['mes'] as num).toInt(),
        total: (row['total'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<Lancamento>> getReceitasDoMes(int ano, int mes) async {
    final db = await _db;

    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);

    final result = await db.query(
      'lancamentos',
      where: '''
        data_hora >= ?
        AND data_hora < ?
        AND tipo_movimento = ?
      ''',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
        tipoReceitaDb,
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }
}
