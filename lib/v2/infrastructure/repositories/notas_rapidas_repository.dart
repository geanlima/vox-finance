import 'package:sqflite/sqflite.dart';

class NotaRapidaItem {
  final int id;
  final String texto;
  final bool concluida;
  final int ordem;
  final DateTime criadoEm;

  const NotaRapidaItem({
    required this.id,
    required this.texto,
    required this.concluida,
    required this.ordem,
    required this.criadoEm,
  });

  static NotaRapidaItem fromMap(Map<String, Object?> m) {
    return NotaRapidaItem(
      id: (m['id'] as int),
      texto: (m['texto'] as String),
      concluida: (m['concluida'] as int) == 1,
      ordem: (m['ordem'] as int?) ?? 0,
      criadoEm:
          DateTime.tryParse((m['criado_em'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class NotasRapidasRepository {
  final Database db;
  const NotasRapidasRepository(this.db);

  Future<List<NotaRapidaItem>> listar() async {
    final rows = await db.query('notas_rapidas', orderBy: 'ordem ASC, id DESC');
    return rows.map(NotaRapidaItem.fromMap).toList();
  }

  Future<int> adicionar(String texto, {int ordem = 0}) async {
    return db.insert('notas_rapidas', {
      'texto': texto.trim(),
      'concluida': 0,
      'ordem': ordem,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setConcluida(int id, bool value) async {
    await db.update(
      'notas_rapidas',
      {'concluida': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remover(int id) async {
    await db.delete('notas_rapidas', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> limparConcluidas() async {
    await db.delete('notas_rapidas', where: 'concluida = 1');
  }
}
