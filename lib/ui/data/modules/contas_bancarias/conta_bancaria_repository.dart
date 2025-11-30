import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class ContaBancariaRepository {
  final DbService _dbService;

  ContaBancariaRepository({DbService? dbService})
    : _dbService = dbService ?? DbService.instance;

  // ============================================================
  //  CRUD  C O N T A   B A N C Á R I A
  // ============================================================

  Future<int> salvarContaBancaria(ContaBancaria conta) async {
    final database = await _dbService.db;
    final dados = conta.toMap();

    if (conta.id == null) {
      dados.remove('id');
      final id = await database.insert(
        'conta_bancaria',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      conta.id = id;
      return id;
    } else {
      return await database.update(
        'conta_bancaria',
        dados,
        where: 'id = ?',
        whereArgs: [conta.id],
      );
    }
  }

  Future<List<ContaBancaria>> getContasBancarias({
    bool apenasAtivas = false,
  }) async {
    final database = await _dbService.db;

    final result = await database.query(
      'conta_bancaria',
      where: apenasAtivas ? 'ativa = 1' : null,
      orderBy: 'descricao ASC',
    );

    return result.map((e) => ContaBancaria.fromMap(e)).toList();
  }

  Future<void> deletarContaBancaria(int id) async {
    final database = await _dbService.db;
    await database.delete('conta_bancaria', where: 'id = ?', whereArgs: [id]);
  }
}
