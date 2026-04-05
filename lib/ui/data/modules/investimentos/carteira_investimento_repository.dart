import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/bluminers_config.dart';
import 'package:vox_finance/ui/data/models/investimento_carteira.dart';

class CarteiraInvestimentoRepository {
  static const _tbl = 'investimento_carteiras';

  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<InvestimentoCarteira>> listar() async {
    final db = await _db;
    final rows = await db.query(_tbl, orderBy: 'nome COLLATE NOCASE ASC');
    return rows.map((e) => InvestimentoCarteira.fromMap(e)).toList();
  }

  Future<InvestimentoCarteira?> porId(int id) async {
    final db = await _db;
    final rows = await db.query(_tbl, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InvestimentoCarteira.fromMap(rows.first);
  }

  /// Cria carteira + linha de config Bluminers vazia para o layout bluminers.
  Future<int> salvar(InvestimentoCarteira c) async {
    final db = await _db;
    if (c.id == null) {
      final dados = c.toMap()..remove('id');
      final id = await db.insert(_tbl, dados);
      await db.insert(
        'investimento_bluminers_config',
        BluminersConfig(
          idCarteira: id,
          saldoInicialInvestido: 0,
          saldoInicialDisponivel: 0,
          aporteMensal: 0,
          meta: null,
          criadoEm: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return id;
    }
    final dados = c.toMap()..remove('id');
    return db.update(_tbl, dados, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deletar(int id) async {
    if (id == 1) {
      throw StateError('Não é possível excluir a carteira principal.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'investimento_bluminers_movimentos',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'investimento_bluminers_rentabilidade',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'investimento_bluminers_config',
        where: 'id_carteira = ?',
        whereArgs: [id],
      );
      await txn.delete(_tbl, where: 'id = ?', whereArgs: [id]);
    });
  }
}
