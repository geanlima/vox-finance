import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/investimento_cdi_config.dart';

class InvestimentoCdiConfigRepository {
  static const _tbl = 'investimento_cdi_config';
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<InvestimentoCdiConfig?> porCarteira(int idCarteira) async {
    final db = await _db;
    final rows = await db.query(
      _tbl,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return InvestimentoCdiConfig.fromMap(rows.first);
  }

  Future<void> upsert(InvestimentoCdiConfig cfg) async {
    final db = await _db;
    await db.insert(
      _tbl,
      cfg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletarPorCarteira(int idCarteira) async {
    final db = await _db;
    await db.delete(
      _tbl,
      where: 'id_carteira = ?',
      whereArgs: [idCarteira],
    );
  }
}

