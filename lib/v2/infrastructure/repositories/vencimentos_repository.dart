import 'package:sqflite/sqflite.dart';

class VencimentoItem {
  final int id;
  final String titulo;
  final DateTime data;
  final int? valorCentavos;
  final String? observacao;
  final bool pago;
  final String recorrencia; // nenhuma | mensal
  final int? origemId;

  const VencimentoItem({
    required this.id,
    required this.titulo,
    required this.data,
    required this.valorCentavos,
    required this.observacao,
    required this.pago,
    required this.recorrencia,
    required this.origemId,
  });

  static DateTime _parseDate(String s) {
    final parts = s.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static VencimentoItem fromMap(Map<String, Object?> m) {
    return VencimentoItem(
      id: m['id'] as int,
      titulo: m['titulo'] as String,
      data: _parseDate(m['data'] as String),
      valorCentavos: m['valor_centavos'] as int?,
      observacao: m['observacao'] as String?,
      pago: (m['pago'] as int) == 1,
      recorrencia: (m['recorrencia'] as String?) ?? 'nenhuma',
      origemId: m['origem_id'] as int?,
    );
  }
}

class VencimentosRepository {
  final Database db;
  const VencimentosRepository(this.db);

  Future<List<VencimentoItem>> listarPorMes(DateTime mes) async {
    final first = DateTime(mes.year, mes.month, 1);
    final last = DateTime(mes.year, mes.month + 1, 0);
    final a = _fmt(first);
    final b = _fmt(last);

    final rows = await db.query(
      'vencimentos',
      where: 'data >= ? AND data <= ?',
      whereArgs: [a, b],
      orderBy: 'data ASC, pago ASC, id DESC',
    );
    return rows.map(VencimentoItem.fromMap).toList();
  }

  Future<List<VencimentoItem>> listarPorDia(DateTime dia) async {
    final d = _fmt(dia);
    final rows = await db.query(
      'vencimentos',
      where: 'data = ?',
      whereArgs: [d],
      orderBy: 'pago ASC, id DESC',
    );
    return rows.map(VencimentoItem.fromMap).toList();
  }

  Future<int> adicionar({
    required String titulo,
    required DateTime data,
    int? valorCentavos,
    String? observacao,
    String recorrencia = 'nenhuma',
    int? origemId,
  }) async {
    return db.insert('vencimentos', {
      'titulo': titulo.trim(),
      'data': _fmt(data),
      'valor_centavos': valorCentavos,
      'observacao': observacao,
      'pago': 0,
      'recorrencia': recorrencia,
      'origem_id': origemId,
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setPago(int id, bool pago) async {
    await db.update(
      'vencimentos',
      {'pago': pago ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remover(int id) async {
    await db.delete('vencimentos', where: 'id = ?', whereArgs: [id]);
  }

  // util
  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
