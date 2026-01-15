import 'package:sqflite/sqflite.dart';

class GanhoRow {
  final int id;
  final String descricao;
  final int valorCentavos;
  final String dataIso; // yyyy-MM-dd
  final String status; // pendente | recebido
  final int anoRef;
  final int mesRef;

  GanhoRow({
    required this.id,
    required this.descricao,
    required this.valorCentavos,
    required this.dataIso,
    required this.status,
    required this.anoRef,
    required this.mesRef,
  });

  factory GanhoRow.fromMap(Map<String, dynamic> map) => GanhoRow(
    id: map['id'] as int,
    descricao: map['descricao'] as String,
    valorCentavos: map['valor_centavos'] as int,
    dataIso: map['data_iso'] as String,
    status: map['status'] as String,
    anoRef: map['ano_ref'] as int,
    mesRef: map['mes_ref'] as int,
  );
}

class GanhosRepository {
  final Database db;

  GanhosRepository(this.db);

  Future<List<GanhoRow>> listarNoMes(
    int ano,
    int mes, {
    bool somenteRecebidos = false,
  }) async {
    final where = StringBuffer('ano_ref = ? AND mes_ref = ?');
    final args = <Object>[ano, mes];

    if (somenteRecebidos) {
      where.write(" AND status = 'recebido'");
    }

    final res = await db.query(
      'ganhos',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'data_iso DESC, id DESC',
    );

    return res.map(GanhoRow.fromMap).toList();
  }

  Future<int> totalNoMes(
    int ano,
    int mes, {
    bool somenteRecebidos = false,
  }) async {
    final where = StringBuffer('ano_ref = ? AND mes_ref = ?');
    final args = <Object>[ano, mes];

    if (somenteRecebidos) {
      where.write(" AND status = 'recebido'");
    }

    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_centavos), 0) AS total
      FROM ganhos
      WHERE ${where.toString()}
      ''', args);

    final v = res.first['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> inserir({
    required String descricao,
    required int valorCentavos,
    required DateTime data,
    required String status,
  }) async {
    final iso =
        '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';

    await db.insert('ganhos', {
      'descricao': descricao,
      'valor_centavos': valorCentavos,
      'data_iso': iso,
      'status': status,
      'ano_ref': data.year,
      'mes_ref': data.month,
    });
  }

  Future<void> atualizarStatus(int id, String status) async {
    await db.update(
      'ganhos',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    await db.delete('ganhos', where: 'id = ?', whereArgs: [id]);
  }
}
