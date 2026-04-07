import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';

class SubcategoriaPersonalizadaRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<int> salvar(SubcategoriaPersonalizada sub) async {
    final db = await _db;
    final dados = sub.toMap()..remove('id');

    if (sub.id == null) {
      return db.insert(
        'subcategorias_personalizadas',
        {
          ...dados,
          'criado_em': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return db.update(
      'subcategorias_personalizadas',
      dados,
      where: 'id = ?',
      whereArgs: [sub.id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete(
      'subcategorias_personalizadas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SubcategoriaPersonalizada>> listarPorCategoria(int categoriaId) async {
    final db = await _db;
    final result = await db.query(
      'subcategorias_personalizadas',
      where: 'id_categoria_personalizada = ?',
      whereArgs: [categoriaId],
      orderBy: 'nome',
    );
    return result.map((m) => SubcategoriaPersonalizada.fromMap(m)).toList();
  }

  Future<List<SubcategoriaPersonalizada>> listarTodasComCategoriaTipo() async {
    final db = await _db;

    final result = await db.rawQuery('''
      SELECT
        s.id,
        s.id_categoria_personalizada,
        s.nome,
        c.tipo_movimento AS tipo_movimento_categoria
      FROM subcategorias_personalizadas s
      JOIN categorias_personalizadas c ON c.id = s.id_categoria_personalizada
      ORDER BY c.nome, s.nome;
    ''');

    return result
        .map((m) => SubcategoriaPersonalizada.fromMap(m))
        .toList();
  }
}

