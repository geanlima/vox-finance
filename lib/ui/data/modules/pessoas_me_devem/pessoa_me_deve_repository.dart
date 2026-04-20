import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/pessoa_me_deve.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class PessoaMeDeveRepository {
  final DbService _dbService;

  PessoaMeDeveRepository({DbService? dbService})
    : _dbService = dbService ?? DbService.instance;

  Future<Database> get _db async => _dbService.db;

  Future<List<PessoaMeDeve>> listar() async {
    final db = await _db;
    final rows = await db.query(
      'pessoas_me_devem',
      orderBy: 'data_emprestimo DESC, id DESC',
    );
    return rows.map(PessoaMeDeve.fromMap).toList();
  }

  Future<double> totalPendente() async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(valor_total - valor_recebido), 0) AS t
      FROM pessoas_me_devem
      WHERE (valor_total - valor_recebido) > 0.009
    ''');
    return (res.first['t'] as num?)?.toDouble() ?? 0;
  }

  Future<int> inserir({
    required String nome,
    required DateTime dataEmprestimo,
    required double valorTotal,
    String? observacao,
  }) async {
    final db = await _db;
    final agora = DateTime.now().millisecondsSinceEpoch;
    final d = DateTime(dataEmprestimo.year, dataEmprestimo.month, dataEmprestimo.day);
    return db.insert('pessoas_me_devem', {
      'nome': nome.trim(),
      'data_emprestimo': d.millisecondsSinceEpoch,
      'valor_total': valorTotal,
      'valor_recebido': 0.0,
      'observacao': observacao?.trim().isEmpty == true ? null : observacao?.trim(),
      'criado_em': agora,
    });
  }

  Future<void> atualizar(PessoaMeDeve p) async {
    final db = await _db;
    if (p.id == null) return;
    await db.update(
      'pessoas_me_devem',
      {
        'nome': p.nome.trim(),
        'data_emprestimo': DateTime(
          p.dataEmprestimo.year,
          p.dataEmprestimo.month,
          p.dataEmprestimo.day,
        ).millisecondsSinceEpoch,
        'valor_total': p.valorTotal,
        'observacao':
            p.observacao?.trim().isEmpty == true ? null : p.observacao?.trim(),
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('pessoas_me_devem', where: 'id = ?', whereArgs: [id]);
  }

  /// Registra recebimento parcial ou total: grava [Lancamento] como receita (pago)
  /// e atualiza [valor_recebido].
  Future<void> registrarRecebimentoComLancamento({
    required int idPessoa,
    required double valor,
    required DateTime dataRecebimento,
    required FormaPagamento formaPagamento,
    int? idConta,
  }) async {
    if (valor <= 0) return;
    final db = await _db;

    final rows = await db.query(
      'pessoas_me_devem',
      where: 'id = ?',
      whereArgs: [idPessoa],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final p = PessoaMeDeve.fromMap(rows.first);
    final pendente = p.valorPendente;
    if (pendente <= 0) return;

    final creditar = valor > pendente ? pendente : valor;

    final dtPag = DateTime(
      dataRecebimento.year,
      dataRecebimento.month,
      dataRecebimento.day,
    );

    final obs = p.observacao;
    final desc =
        obs != null && obs.isNotEmpty
            ? 'Recebimento: ${p.nome} — $obs'
            : 'Recebimento: ${p.nome}';

    await db.transaction((txn) async {
      final lanc = Lancamento(
        valor: creditar,
        descricao: desc,
        formaPagamento: formaPagamento,
        dataHora: dtPag,
        pagamentoFatura: false,
        pago: true,
        dataPagamento: dtPag,
        categoria: Categoria.financasPessoais,
        tipoMovimento: TipoMovimento.receita,
        idConta: idConta,
      );

      final map = lanc.toMap()..remove('id');
      await txn.insert(
        'lancamentos',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final novo = p.valorRecebido + creditar;
      await txn.update(
        'pessoas_me_devem',
        {'valor_recebido': novo},
        where: 'id = ?',
        whereArgs: [idPessoa],
      );
    });
  }
}
