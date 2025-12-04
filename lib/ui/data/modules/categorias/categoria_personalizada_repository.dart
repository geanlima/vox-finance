import 'package:sqflite/sqflite.dart';

import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart'; // por causa do enum TipoMovimento

class CategoriaPersonalizadaRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  // ----------------- SALVAR (insert/update) -----------------
  Future<int> salvar(CategoriaPersonalizada cat) async {
    final db = await _db;

    final dados = cat.toMap()..remove('id');

    if (cat.id == null) {
      // insert
      return db.insert(
        'categorias_personalizadas',
        dados,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // update
      return db.update(
        'categorias_personalizadas',
        dados,
        where: 'id = ?',
        whereArgs: [cat.id],
      );
    }
  }

  // ----------------- NOVO: listar por tipo -----------------
  Future<List<CategoriaPersonalizada>> listarPorTipo(TipoMovimento tipo) async {
    final db = await _db;

    // gravamos como texto: 'receita' ou 'despesa'
    final tipoStr = tipo == TipoMovimento.receita ? 'receita' : 'despesa';

    final result = await db.query(
      'categorias_personalizadas',
      //where: 'tipo_movimento = ?',
      //whereArgs: [tipoStr],
      orderBy: 'nome',
    );

    return result.map((m) => CategoriaPersonalizada.fromMap(m)).toList();
  }

  // (opcional) listar todas – se sua tela de cadastro usar
  Future<List<CategoriaPersonalizada>> listarTodas() async {
    final db = await _db;
    final result = await db.query('categorias_personalizadas', orderBy: 'nome');
    return result.map((m) => CategoriaPersonalizada.fromMap(m)).toList();
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete(
      'categorias_personalizadas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
