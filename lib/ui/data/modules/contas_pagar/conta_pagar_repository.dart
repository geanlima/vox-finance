// lib/ui/data/modules/contas_pagar/conta_pagar_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';

class ContaPagarRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  // ============================================================
  //  C R U D   B Á S I C O
  // ============================================================

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
