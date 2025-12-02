// lib/ui/data/modules/lancamentos/lancamento_repository.dart
import 'dart:math';
import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';

class LancamentoRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

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
        // mesmo que base tenha id, vamos ignorar no insert
        id: null,
        valor: valorParcela,
        dataHora: dataParcela,
        grupoParcelas: grupo,
        parcelaNumero: i + 1,
        parcelaTotal: qtdParcelas,
        pago: pagoBase,
        dataPagamento: dataPagamentoBase,
      );

      // 🔴 IMPORTANTE: remover o id do map antes de inserir
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

      // garante que nunca vai tentar inserir id manual
      final dadosConta = conta.toMap()..remove('id');

      await db.insert('conta_pagar', dadosConta);
    }
  }
}
