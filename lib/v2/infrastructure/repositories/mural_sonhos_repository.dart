import 'package:sqflite/sqflite.dart';

class MuralSonhoRow {
  final int id;
  final String titulo;
  final String? imagemPath;
  final double valorObjetivo;
  final int anoPrazo;
  final int prazoTipo; // 1 curto / 2 medio / 3 longo
  final bool status; // true = bati
  final String createdAt;
  final String? updatedAt;

  const MuralSonhoRow({
    required this.id,
    required this.titulo,
    required this.imagemPath,
    required this.valorObjetivo,
    required this.anoPrazo,
    required this.prazoTipo,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MuralSonhoRow.fromMap(Map<String, Object?> m) {
    double d(Object? v) =>
        (v is int) ? v.toDouble() : (v as num?)?.toDouble() ?? 0.0;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    return MuralSonhoRow(
      id: i(m['id']),
      titulo: (m['titulo'] as String?) ?? '',
      imagemPath: m['imagem_path'] as String?,
      valorObjetivo: d(m['valor_objetivo']),
      anoPrazo: i(m['ano_prazo']),
      prazoTipo: i(m['prazo_tipo']),
      status: i(m['status']) == 1,
      createdAt: (m['created_at'] as String?) ?? '',
      updatedAt: m['updated_at'] as String?,
    );
  }

  String get prazoLabel {
    switch (prazoTipo) {
      case 1:
        return 'Curto prazo';
      case 2:
        return 'Médio prazo';
      default:
        return 'Longo prazo';
    }
  }

  String get statusLabel => status ? 'Bati' : 'Ainda não bati';
}

class MuralSonhosRepository {
  static const table = 'mural_sonhos';

  final Database _db;
  MuralSonhosRepository(this._db);

  Future<List<MuralSonhoRow>> listar() async {
    final rows = await _db.query(
      table,
      orderBy: 'status ASC, ano_prazo ASC, id DESC',
    );
    return rows.map(MuralSonhoRow.fromMap).toList();
  }

  Future<int> inserir({
    required String titulo,
    String? imagemPath,
    required double valorObjetivo,
    required int anoPrazo,
    required int prazoTipo,
    bool status = false,
  }) async {
    final id = await _db.insert(table, {
      'titulo': titulo.trim(),
      'imagem_path':
          (imagemPath?.trim().isEmpty ?? true) ? null : imagemPath!.trim(),
      'valor_objetivo': valorObjetivo,
      'ano_prazo': anoPrazo,
      'prazo_tipo': prazoTipo,
      'status': status ? 1 : 0,
      'updated_at': null,
    });

    await _db.execute(
      "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
      [id],
    );

    return id;
  }

  Future<void> atualizar({
    required int id,
    required String titulo,
    String? imagemPath,
    required double valorObjetivo,
    required int anoPrazo,
    required int prazoTipo,
  }) async {
    await _db.transaction((txn) async {
      await txn.update(
        table,
        {
          'titulo': titulo.trim(),
          'imagem_path':
              (imagemPath?.trim().isEmpty ?? true) ? null : imagemPath!.trim(),
          'valor_objetivo': valorObjetivo,
          'ano_prazo': anoPrazo,
          'prazo_tipo': prazoTipo,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.execute(
        "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
        [id],
      );
    });
  }

  Future<void> setStatus(int id, bool bati) async {
    await _db.transaction((txn) async {
      await txn.update(
        table,
        {'status': bati ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.execute(
        "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
        [id],
      );
    });
  }

  Future<void> remover(int id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
