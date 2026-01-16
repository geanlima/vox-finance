import 'package:sqflite/sqflite.dart';

class PessoaDevedoraRow {
  final int id;
  final String nomeDevedor;
  final String descricao;
  final String? combinado;
  final String dataEmprestimoIso;
  final int valorTotalCentavos;
  final int valorPagoCentavos;
  final String status;

  PessoaDevedoraRow({
    required this.id,
    required this.nomeDevedor,
    required this.descricao,
    this.combinado,
    required this.dataEmprestimoIso,
    required this.valorTotalCentavos,
    required this.valorPagoCentavos,
    required this.status,
  });

  int get valorPendenteCentavos => valorTotalCentavos - valorPagoCentavos;

  bool get isPago => status == 'pago';

  factory PessoaDevedoraRow.fromMap(Map<String, dynamic> map) {
    return PessoaDevedoraRow(
      id: map['id'] as int,
      nomeDevedor: map['nome_devedor'] as String,
      descricao: map['descricao'] as String,
      combinado: map['combinado'] as String?,
      dataEmprestimoIso: map['data_emprestimo'] as String,
      valorTotalCentavos: map['valor_total_centavos'] as int,
      valorPagoCentavos: map['valor_pago_centavos'] as int,
      status: map['status'] as String,
    );
  }
}

class PessoasDevedorasRepository {
  final Database db;
  PessoasDevedorasRepository(this.db);

  Future<List<PessoaDevedoraRow>> listar() async {
    final res = await db.query(
      'pessoas_devedoras',
      orderBy: 'status ASC, data_emprestimo DESC',
    );
    return res.map(PessoaDevedoraRow.fromMap).toList();
  }

  Future<int> totalPendente() async {
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_total_centavos - valor_pago_centavos), 0) AS total
      FROM pessoas_devedoras
      WHERE status != 'pago'
    ''');
    return (res.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> inserir({
    required String nomeDevedor,
    required String descricao,
    String? combinado,
    required DateTime dataEmprestimo,
    required int valorTotalCentavos,
  }) async {
    final iso =
        '${dataEmprestimo.year.toString().padLeft(4, '0')}-'
        '${dataEmprestimo.month.toString().padLeft(2, '0')}-'
        '${dataEmprestimo.day.toString().padLeft(2, '0')}';

    await db.insert('pessoas_devedoras', {
      'nome_devedor': nomeDevedor,
      'descricao': descricao,
      'combinado': combinado,
      'data_emprestimo': iso,
      'valor_total_centavos': valorTotalCentavos,
      'valor_pago_centavos': 0,
      'status': 'pendente',
    });
  }

  Future<void> registrarPagamento(int id, int valorPagoCentavos) async {
    final row =
        (await db.query(
          'pessoas_devedoras',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        )).first;

    final novoPago = (row['valor_pago_centavos'] as int) + valorPagoCentavos;
    final total = row['valor_total_centavos'] as int;

    await db.update(
      'pessoas_devedoras',
      {
        'valor_pago_centavos': novoPago,
        'status': novoPago >= total ? 'pago' : 'pendente',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletar(int id) async {
    await db.delete('pessoas_devedoras', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> marcarComoPago(int id) async {
    final res = await db.query(
      'pessoas_devedoras',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return;

    final total = (res.first['valor_total_centavos'] as int?) ?? 0;

    await db.update(
      'pessoas_devedoras',
      {
        'valor_pago_centavos': total,
        'status': 'pago',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
