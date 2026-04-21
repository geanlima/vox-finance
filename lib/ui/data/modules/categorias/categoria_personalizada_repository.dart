// ignore_for_file: unused_local_variable

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

    // Receita/despesa no lançamento também listam categorias marcadas como "Ambos".
    final idxAmbos = TipoMovimento.ambos.index;
    final result = await db.query(
      'categorias_personalizadas',
      where: '(tipo_movimento = ? OR tipo_movimento = ?)',
      whereArgs: [tipo.index, idxAmbos],
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

  Future<CategoriaPersonalizada> getOrCreate({
    required String nome,
    required TipoMovimento tipoMovimento,
    String? corHex,
  }) async {
    final db = await _db;
    final nomeNorm = nome.trim();

    final rows = await db.query(
      'categorias_personalizadas',
      where: 'LOWER(nome) = LOWER(?)',
      whereArgs: [nomeNorm],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return CategoriaPersonalizada.fromMap(rows.first);
    }

    final id = await salvar(
      CategoriaPersonalizada(
        nome: nomeNorm,
        tipoMovimento: tipoMovimento,
        corHex: corHex,
      ),
    );

    return CategoriaPersonalizada(
      id: id,
      nome: nomeNorm,
      tipoMovimento: tipoMovimento,
      corHex: corHex,
    );
  }
}
