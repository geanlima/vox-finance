import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/fonte_renda.dart';
import 'package:vox_finance/ui/data/models/destino_renda.dart';

class RendaRepository {
  final DbService _dbService;

  RendaRepository({DbService? dbService})
      : _dbService = dbService ?? DbService();

  Future<Database> get _db async => _dbService.db;

  // ========== FONTES ==========

  Future<int> inserirFonte(FonteRenda fonte) async {
    final db = await _db;
    final dados = fonte.toMap()..remove('id');
    return db.insert('fontes_renda', dados);
  }

  Future<int> atualizarFonte(FonteRenda fonte) async {
    if (fonte.id == null) {
      throw ArgumentError('FonteRenda sem id para atualizar.');
    }
    final db = await _db;
    return db.update(
      'fontes_renda',
      fonte.toMap(),
      where: 'id = ?',
      whereArgs: [fonte.id],
    );
  }

  /// Conveniência: se não tem id -> insere, senão -> atualiza
  Future<int> salvarFonte(FonteRenda fonte) async {
    if (fonte.id == null) {
      return inserirFonte(fonte);
    } else {
      return atualizarFonte(fonte);
    }
  }

  Future<int> deletarFonte(int id) async {
    final db = await _db;
    // apaga destinos vinculados
    await db.delete(
      'destinos_renda',
      where: 'id_fonte = ?',
      whereArgs: [id],
    );
    return db.delete(
      'fontes_renda',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FonteRenda>> listarFontes({bool? apenasAtivas}) async {
    final db = await _db;
    String? where;
    List<Object?>? whereArgs;

    if (apenasAtivas == true) {
      where = 'ativa = 1';
    }

    final result = await db.query(
      'fontes_renda',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'nome ASC',
    );

    return result.map((m) => FonteRenda.fromMap(m)).toList();
  }

  Future<FonteRenda?> obterFontePorId(int id) async {
    final db = await _db;
    final result = await db.query(
      'fontes_renda',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return FonteRenda.fromMap(result.first);
  }

  // ========== DESTINOS (percentuais) ==========

  // mantém compatibilidade com o nome antigo se já estiver usando
  Future<List<DestinoRenda>> listarDestinosPorFonte(int idFonte) =>
      listarDestinosDaFonte(idFonte);

  Future<List<DestinoRenda>> listarDestinosDaFonte(int idFonte) async {
    final db = await _db;
    final result = await db.query(
      'destinos_renda',
      where: 'id_fonte = ?',
      whereArgs: [idFonte],
      orderBy: 'nome ASC',
    );
    return result.map((m) => DestinoRenda.fromMap(m)).toList();
  }

  Future<int> inserirDestino(DestinoRenda destino) async {
    final db = await _db;
    final dados = destino.toMap()..remove('id');
    return db.insert('destinos_renda', dados);
  }

  Future<int> atualizarDestino(DestinoRenda destino) async {
    if (destino.id == null) {
      throw ArgumentError('DestinoRenda sem id para atualizar.');
    }
    final db = await _db;
    return db.update(
      'destinos_renda',
      destino.toMap(),
      where: 'id = ?',
      whereArgs: [destino.id],
    );
  }

  Future<int> deletarDestino(int id) async {
    final db = await _db;
    return db.delete(
      'destinos_renda',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soma dos percentuais configurados para uma fonte (para validar == 100).
  Future<double> somaPercentuaisDaFonte(int idFonte) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT SUM(percentual) as total FROM destinos_renda WHERE id_fonte = ?',
      [idFonte],
    );
    if (result.isEmpty || result.first['total'] == null) return 0.0;
    return (result.first['total'] as num).toDouble();
  }

  // INSERIR / ATUALIZAR destino de renda
  Future<int> salvarDestino(DestinoRenda destino) async {
    if (destino.id == null) {
      return inserirDestino(destino);
    } else {
      return atualizarDestino(destino);
    }
  }
}
