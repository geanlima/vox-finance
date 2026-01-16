import 'package:sqflite/sqflite.dart';

class InvestimentoRow {
  final int id;
  final int tipo;
  final String? instituicao;
  final String ativo;
  final String? categoria;

  final double valorAplicado;
  final double quantidade;
  final double precoMedio;

  final String? dataAporte;
  final String? vencimento;

  final int rentabilidadeTipo;
  final double rentabilidadeValor;

  final String? observacoes;
  final bool ativoFlag;

  final String createdAt;
  final String? updatedAt;

  const InvestimentoRow({
    required this.id,
    required this.tipo,
    required this.instituicao,
    required this.ativo,
    required this.categoria,
    required this.valorAplicado,
    required this.quantidade,
    required this.precoMedio,
    required this.dataAporte,
    required this.vencimento,
    required this.rentabilidadeTipo,
    required this.rentabilidadeValor,
    required this.observacoes,
    required this.ativoFlag,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvestimentoRow.fromMap(Map<String, Object?> m) {
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    double d(Object? v) => (v as num?)?.toDouble() ?? 0.0;

    return InvestimentoRow(
      id: i(m['id']),
      tipo: i(m['tipo']),
      instituicao: m['instituicao'] as String?,
      ativo: (m['ativo'] as String?) ?? '',
      categoria: m['categoria'] as String?,
      valorAplicado: d(m['valor_aplicado']),
      quantidade: d(m['quantidade']),
      precoMedio: d(m['preco_medio']),
      dataAporte: m['data_aporte'] as String?,
      vencimento: m['vencimento'] as String?,
      rentabilidadeTipo: i(m['rentabilidade_tipo']),
      rentabilidadeValor: d(m['rentabilidade_valor']),
      observacoes: m['observacoes'] as String?,
      ativoFlag: i(m['ativo_flag']) == 1,
      createdAt: (m['created_at'] as String?) ?? '',
      updatedAt: m['updated_at'] as String?,
    );
  }

  String get tipoLabel {
    switch (tipo) {
      case 1:
        return 'Renda Fixa';
      case 2:
        return 'Ações';
      case 3:
        return 'FIIs';
      case 4:
        return 'Cripto';
      case 5:
        return 'Fundos';
      default:
        return 'Outros';
    }
  }
}

class InvestimentosRepository {
  static const table = 'investimentos';
  final Database _db;
  InvestimentosRepository(this._db);

  Future<List<InvestimentoRow>> listar({
    int? tipo,
    bool? apenasAtivos,
    String? busca,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (tipo != null) {
      where.add('tipo = ?');
      args.add(tipo);
    }
    if (apenasAtivos == true) {
      where.add('ativo_flag = 1');
    }
    if (busca != null && busca.trim().isNotEmpty) {
      where.add('(ativo LIKE ? OR instituicao LIKE ? OR categoria LIKE ?)');
      final q = '%${busca.trim()}%';
      args.addAll([q, q, q]);
    }

    final rows = await _db.query(
      table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'ativo_flag DESC, tipo ASC, ativo ASC, id DESC',
    );

    return rows.map(InvestimentoRow.fromMap).toList();
  }

  Future<int> inserir({
    required int tipo,
    String? instituicao,
    required String ativo,
    String? categoria,
    double valorAplicado = 0,
    double quantidade = 0,
    double precoMedio = 0,
    String? dataAporte,
    String? vencimento,
    int rentabilidadeTipo = 0,
    double rentabilidadeValor = 0,
    String? observacoes,
    bool ativoFlag = true,
  }) async {
    return _db.insert(table, {
      'tipo': tipo,
      'instituicao':
          (instituicao?.trim().isEmpty ?? true) ? null : instituicao!.trim(),
      'ativo': ativo.trim(),
      'categoria':
          (categoria?.trim().isEmpty ?? true) ? null : categoria!.trim(),
      'valor_aplicado': valorAplicado,
      'quantidade': quantidade,
      'preco_medio': precoMedio,
      'data_aporte':
          (dataAporte?.trim().isEmpty ?? true) ? null : dataAporte!.trim(),
      'vencimento':
          (vencimento?.trim().isEmpty ?? true) ? null : vencimento!.trim(),
      'rentabilidade_tipo': rentabilidadeTipo,
      'rentabilidade_valor': rentabilidadeValor,
      'observacoes':
          (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
      'ativo_flag': ativoFlag ? 1 : 0,
      'updated_at': null,
    });
  }

  Future<void> atualizar({
    required int id,
    required int tipo,
    String? instituicao,
    required String ativo,
    String? categoria,
    double valorAplicado = 0,
    double quantidade = 0,
    double precoMedio = 0,
    String? dataAporte,
    String? vencimento,
    int rentabilidadeTipo = 0,
    double rentabilidadeValor = 0,
    String? observacoes,
    bool ativoFlag = true,
  }) async {
    await _db.update(
      table,
      {
        'tipo': tipo,
        'instituicao':
            (instituicao?.trim().isEmpty ?? true) ? null : instituicao!.trim(),
        'ativo': ativo.trim(),
        'categoria':
            (categoria?.trim().isEmpty ?? true) ? null : categoria!.trim(),
        'valor_aplicado': valorAplicado,
        'quantidade': quantidade,
        'preco_medio': precoMedio,
        'data_aporte':
            (dataAporte?.trim().isEmpty ?? true) ? null : dataAporte!.trim(),
        'vencimento':
            (vencimento?.trim().isEmpty ?? true) ? null : vencimento!.trim(),
        'rentabilidade_tipo': rentabilidadeTipo,
        'rentabilidade_valor': rentabilidadeValor,
        'observacoes':
            (observacoes?.trim().isEmpty ?? true) ? null : observacoes!.trim(),
        'ativo_flag': ativoFlag ? 1 : 0,
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

  Future<void> setAtivo(int id, bool ativoFlag) async {
    await _db.update(
      table,
      {'ativo_flag': ativoFlag ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _db.execute(
      "UPDATE $table SET updated_at = datetime('now') WHERE id = ?",
      [id],
    );
  }
}
