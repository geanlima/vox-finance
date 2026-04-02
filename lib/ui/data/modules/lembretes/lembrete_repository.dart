import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/lembrete.dart';

class LembreteRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<Lembrete>> listar({bool incluirConcluidos = true}) async {
    final db = await _db;
    final where = incluirConcluidos ? null : 'concluido = 0';
    final rows = await db.query(
      'lembretes',
      where: where,
      orderBy: 'data_hora ASC',
    );
    return rows.map((e) => Lembrete.fromMap(e)).toList();
  }

  Future<List<Lembrete>> pendentesAte(DateTime limite) async {
    final db = await _db;
    final rows = await db.query(
      'lembretes',
      where: 'concluido = 0 AND data_hora <= ?',
      whereArgs: [limite.millisecondsSinceEpoch],
      orderBy: 'data_hora ASC',
    );
    return rows.map((e) => Lembrete.fromMap(e)).toList();
  }

  Future<List<Lembrete>> pendentesNoIntervalo(DateTime inicio, DateTime fim) async {
    final db = await _db;
    final rows = await db.query(
      'lembretes',
      where: 'concluido = 0 AND data_hora >= ? AND data_hora <= ?',
      whereArgs: [
        inicio.millisecondsSinceEpoch,
        fim.millisecondsSinceEpoch,
      ],
      orderBy: 'data_hora ASC',
    );
    return rows.map((e) => Lembrete.fromMap(e)).toList();
  }

  Future<int> salvar(Lembrete item) async {
    final db = await _db;
    if (item.id == null) {
      final dados = item.toMap()..remove('id');
      final id = await db.insert('lembretes', dados);
      item.id = id;
      return id;
    }
    return db.update(
      'lembretes',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('lembretes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> marcarConcluido(int id, bool concluido) async {
    final db = await _db;
    await db.update(
      'lembretes',
      {'concluido': concluido ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

