// lib/ui/data/modules/lancamentos/lancamento_repository.dart
import 'dart:math';
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
// 👇 NOVO: resumo mensal
import 'package:vox_finance/ui/data/models/renda_mensal_resumo.dart';

class TotaisDia {
  final double totalDespesas;
  final double totalReceitas;

  TotaisDia({required this.totalDespesas, required this.totalReceitas});
}

class LancamentoRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

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

  Future<TotaisDia> getTotaisPorDia(DateTime dia) async {
    final db = await _db;

    // normaliza para início/fim do dia
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fim = inicio.add(const Duration(days: 1));

    // ⚠️ Ajuste os valores de 'despesa' / 'receita' conforme
    // você grava o campo tipo_movimento na tabela (texto, int, etc).
    final result = await db.rawQuery(
      '''
    SELECT
      SUM(CASE WHEN tipo_movimento = 'despesa' THEN valor ELSE 0 END) AS total_despesas,
      SUM(CASE WHEN tipo_movimento = 'receita' THEN valor ELSE 0 END) AS total_receitas
    FROM lancamentos
    WHERE data_hora >= ? AND data_hora < ?
    ''',
      [inicio.toIso8601String(), fim.toIso8601String()],
    );

    final row = result.isNotEmpty ? result.first : <String, Object?>{};

    double ler(String coluna) {
      final v = row[coluna];
      if (v == null) return 0.0;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return TotaisDia(
      totalDespesas: ler('total_despesas'),
      totalReceitas: ler('total_receitas'),
    );
  }

  // ----------------- CRUD básico -----------------

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

  Future<List<Lancamento>> getFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.query(
      'lancamentos',
      where: 'data_hora > ? AND data_hora <= ?',
      whereArgs: [
        DateTime.now().toIso8601String(),
        dataLimite.toIso8601String(),
      ],
      orderBy: 'data_hora ASC',
    );

    return result.map((map) => Lancamento.fromMap(map)).toList();
  }

  Future<double> getTotalFuturosAte(DateTime dataLimite) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
    SELECT SUM(valor) AS total
    FROM lancamentos
    WHERE data_hora > ? AND data_hora <= ?
  ''',
      [DateTime.now().toIso8601String(), dataLimite.toIso8601String()],
    );

    final total = result.first['total'] as double?;
    return total ?? 0.0;
  }

  Future<void> deletar(int id) async {
    final db = await _db;

    // 1) Apaga a parcela de contas a pagar vinculada a este lançamento
    await db.delete('conta_pagar', where: 'id_lancamento = ?', whereArgs: [id]);

    // 2) Apaga o lançamento em si
    await db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
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

  // ----------------- Parcelados + Contas a Pagar -----------------

  /// Mover a lógica que estava no DbService.salvarLancamentosParceladosFuturos
  Future<void> salvarParceladosFuturos(Lancamento base, int qtdParcelas) async {
    final db = await _db;

    // grupo de parcelas como STRING
    final String grupo =
        base.grupoParcelas ?? DateTime.now().millisecondsSinceEpoch.toString();

    final double valorParcela = base.valor / qtdParcelas;
    final DateTime dataCompra = base.dataHora;

    final bool pagoBase = base.pago;
    final DateTime? dataPagamentoBase =
        pagoBase ? (base.dataPagamento ?? DateTime.now()) : null;

    for (int i = 0; i < qtdParcelas; i++) {
      DateTime dataParcela;

      if (i == 0) {
        // 1ª parcela exatamente na data da compra
        dataParcela = dataCompra;
      } else {
        // Próximas parcelas: mês a mês, ajustando dia se precisar
        final DateTime mesBase = DateTime(
          dataCompra.year,
          dataCompra.month + i,
          1,
          dataCompra.hour,
          dataCompra.minute,
          dataCompra.second,
          dataCompra.millisecond,
        );

        // Último dia do mês de destino
        final int ultimoDiaMes =
            DateTime(mesBase.year, mesBase.month + 1, 0).day;

        final int diaCorreto = min(dataCompra.day, ultimoDiaMes);

        dataParcela = DateTime(
          mesBase.year,
          mesBase.month,
          diaCorreto,
          dataCompra.hour,
          dataCompra.minute,
          dataCompra.second,
          dataCompra.millisecond,
        );
      }

      final lancParcela = base.copyWith(
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoBase,
        dataPagamento: dataPagamentoBase,
      );

      final dadosLanc = lancParcela.toMap()..remove('id');

      final int idLancamento = await db.insert('lancamentos', dadosLanc);

      final conta = ContaPagar(
        id: null,
        descricao: lancParcela.descricao,
        valor: valorParcela,
        dataVencimento: dataParcela,
        pago: false,
        dataPagamento: null,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        grupoParcelas: grupo,
        idLancamento: idLancamento,
      );

      final dadosConta = conta.toMap()..remove('id');

      await db.insert('conta_pagar', dadosConta);
    }
  }

  // -------------------------------------------------
  // NOVO: Resumo mensal de RECEITAS (Minha Renda)
  // -------------------------------------------------

  /// Retorna, para cada mês/ano, o total de RECEITAS.
  ///
  /// Aqui estou considerando receita = valor > 0.
  /// Se no seu app for por categoria/flag, ajuste o WHERE.
  Future<List<RendaMensalResumo>> getResumoRendaMensal() async {
    final db = await _db;

    // valor inteiro correspondente a Receita no seu enum
    const int tipoReceitaDb = 2; // ajuste se o enum for diferente

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

  /// Lista TODAS as receitas de um mês específico (para o detalhe ao clicar).
  Future<List<Lancamento>> getReceitasDoMes(int ano, int mes) async {
    final db = await _db;

    final inicio = DateTime(ano, mes, 1);
    final fim = DateTime(ano, mes + 1, 1);

    final result = await db.query(
      'lancamentos',
      where: '''
      data_hora >= ? 
      AND data_hora < ?
      AND tipo_Movimento = 'receita'
    ''',
      whereArgs: [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );

    return result.map((e) => Lancamento.fromMap(e)).toList();
  }
}
