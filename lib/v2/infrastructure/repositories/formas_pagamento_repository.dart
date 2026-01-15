import 'package:sqflite/sqflite.dart';

class FormaPagamentoRow {
  final int id;
  final String nome;
  final bool ativo;

  // novos campos
  final String
  tipo; // cartao_credito | pix | dinheiro | debito | transferencia | outros
  final bool principal;

  final int? limiteCentavos; // só cartão
  final int? diaFechamento; // só cartão
  final int? diaVencimento; // só cartão

  final String? alias; // opcional (ex: "Cartão Principal", "Acumula pontos")

  const FormaPagamentoRow({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.tipo,
    required this.principal,
    this.limiteCentavos,
    this.diaFechamento,
    this.diaVencimento,
    this.alias,
  });

  bool get isCartaoCredito => tipo == 'cartao_credito';

  String get tipoLabel {
    switch (tipo) {
      case 'cartao_credito':
        return 'Cartão de crédito';
      case 'pix':
        return 'PIX';
      case 'dinheiro':
        return 'Dinheiro';
      case 'debito':
        return 'Débito';
      case 'transferencia':
        return 'Transferência';
      default:
        return 'Outros';
    }
  }

  factory FormaPagamentoRow.fromMap(Map<String, Object?> m) {
    return FormaPagamentoRow(
      id: m['id'] as int,
      nome: m['nome'] as String,
      ativo: (m['ativo'] as int) == 1,

      tipo: (m['tipo'] as String?) ?? 'outros',
      principal: ((m['principal'] as int?) ?? 0) == 1,

      limiteCentavos: m['limite_centavos'] as int?,
      diaFechamento: m['dia_fechamento'] as int?,
      diaVencimento: m['dia_vencimento'] as int?,

      alias: m['alias'] as String?,
    );
  }
}

class FormasPagamentoRepository {
  final Database db;
  const FormasPagamentoRepository(this.db);

  Future<List<FormaPagamentoRow>> listarFormas({
    bool apenasAtivas = true,
  }) async {
    final rows = await db.query(
      'formas_pagamento',
      where: apenasAtivas ? 'ativo = 1' : null,
      orderBy: "tipo ASC, principal DESC, nome COLLATE NOCASE ASC",
    );

    return rows.map((m) => FormaPagamentoRow.fromMap(m)).toList();
  }

  Future<int> criarForma({
    required String nome,
    required String tipo, // pix|dinheiro|debito|transferencia|outros
    bool ativo = true,
    String? alias,
  }) async {
    return db.insert('formas_pagamento', {
      'nome': nome.trim(),
      'tipo': tipo,
      'ativo': ativo ? 1 : 0,
      'principal': 0,
      'alias': alias,
      'limite_centavos': null,
      'dia_fechamento': null,
      'dia_vencimento': null,
    });
  }

  Future<int> criarCartaoCredito({
    required String nome,
    int limiteCentavos = 0,
    int diaFechamento = 10,
    int diaVencimento = 17,
    bool principal = false,
    bool ativo = true,
    String? alias,
  }) async {
    final id = await db.insert('formas_pagamento', {
      'nome': nome.trim(),
      'tipo': 'cartao_credito',
      'ativo': ativo ? 1 : 0,
      'principal': principal ? 1 : 0,
      'alias': alias,
      'limite_centavos': limiteCentavos,
      'dia_fechamento': diaFechamento,
      'dia_vencimento': diaVencimento,
    });

    if (principal) {
      await definirComoPrincipal(id);
    }

    return id;
  }

  Future<void> editarForma({
    required int id,
    required String nome,
    required String tipo,
    bool ativo = true,
    String? alias,
  }) async {
    await db.update(
      'formas_pagamento',
      {
        'nome': nome.trim(),
        'tipo': tipo,
        'ativo': ativo ? 1 : 0,
        'alias': alias,
        // mantém campos de cartão intactos
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> editarCartaoCredito({
    required int id,
    required String nome,
    required int limiteCentavos,
    required int diaFechamento,
    required int diaVencimento,
    required bool principal,
    bool ativo = true,
    String? alias,
  }) async {
    await db.update(
      'formas_pagamento',
      {
        'nome': nome.trim(),
        'tipo': 'cartao_credito',
        'ativo': ativo ? 1 : 0,
        'principal': principal ? 1 : 0,
        'alias': alias,
        'limite_centavos': limiteCentavos,
        'dia_fechamento': diaFechamento,
        'dia_vencimento': diaVencimento,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (principal) {
      await definirComoPrincipal(id);
    }
  }

  Future<void> setAtivo(int id, bool ativo) async {
    await db.update(
      'formas_pagamento',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> definirComoPrincipal(int id) async {
    await db.transaction((txn) async {
      await txn.update('formas_pagamento', {'principal': 0});
      await txn.update(
        'formas_pagamento',
        {'principal': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deletar(int id) async {
    await db.delete('formas_pagamento', where: 'id = ?', whereArgs: [id]);
  }
}
