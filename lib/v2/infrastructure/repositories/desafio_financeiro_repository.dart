import 'package:sqflite/sqflite.dart';

class DesafioFinanceiroRow {
  final int id;
  final int mes; // 1..12
  final int ano;
  final String desafio;
  final int status; // 0/1/2
  final bool metaAtingida;
  final String? observacoes;
  final String createdAt;
  final String? updatedAt;

  const DesafioFinanceiroRow({
    required this.id,
    required this.mes,
    required this.ano,
    required this.desafio,
    required this.status,
    required this.metaAtingida,
    required this.observacoes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DesafioFinanceiroRow.fromMap(Map<String, Object?> m) {
    int i(Object? v) => (v as num?)?.toInt() ?? 0;

    return DesafioFinanceiroRow(
      id: i(m['id']),
      mes: i(m['mes']),
      ano: i(m['ano']),
      desafio: (m['desafio'] as String?) ?? '',
      status: i(m['status']),
      metaAtingida: i(m['meta_atingida']) == 1,
      observacoes: m['observacoes'] as String?,
      createdAt: (m['created_at'] as String?) ?? '',
      updatedAt: m['updated_at'] as String?,
    );
  }

  String get mesLabel {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    if (mes < 1 || mes > 12) return 'Mês';
    return meses[mes - 1];
  }

  String get statusLabel {
    switch (status) {
      case 1:
        return 'Em andamento';
      case 2:
        return 'Concluído';
      default:
        return 'Não iniciada';
    }
  }
}

class DesafioFinanceiroRepository {
  static const table = 'desafio_financeiro';

  final Database _db;
  DesafioFinanceiroRepository(this._db);

  Future<List<DesafioFinanceiroRow>> listar({required int ano}) async {
    final rows = await _db.query(
      table,
      where: 'ano = ?',
      whereArgs: [ano],
      orderBy: 'mes ASC',
    );
    return rows.map(DesafioFinanceiroRow.fromMap).toList();
  }

  Future<int> inserir({
    required int mes,
    required int ano,
    required String desafio,
    int status = 0,
    bool metaAtingida = false,
    String? observacoes,
  }) async {
    return _db.insert(table, {
      'mes': mes,
      'ano': ano,
      'desafio': desafio.trim(),
      'status': status,
      'meta_atingida': metaAtingida ? 1 : 0,
      'observacoes':
          (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
      'updated_at': null,
    });
  }

  Future<void> atualizar({
    required int id,
    required int mes,
    required int ano,
    required String desafio,
    required int status,
    required bool metaAtingida,
    String? observacoes,
  }) async {
    await _db.update(
      table,
      {
        'mes': mes,
        'ano': ano,
        'desafio': desafio.trim(),
        'status': status,
        'meta_atingida': metaAtingida ? 1 : 0,
        'observacoes':
            (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _db.execute(
      "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }

  Future<void> remover(int id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setStatus(int id, int status) async {
    await _db.update(
      table,
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.execute(
      "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }

  Future<void> setMetaAtingida(int id, bool metaAtingida) async {
    await _db.update(
      table,
      {'meta_atingida': metaAtingida ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.execute(
      "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }
}
