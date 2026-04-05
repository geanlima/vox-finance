import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa_mes_resumo.dart';

class DespesaFixaRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<List<DespesaFixa>> listar() async {
    final db = await _db;
    final rows = await db.query('despesas_fixas', orderBy: 'descricao ASC');
    return rows.map((e) => DespesaFixa.fromMap(e)).toList();
  }

  Future<int> salvar(DespesaFixa item) async {
    final db = await _db;
    if (item.id == null) {
      final dados = item.toMap()..remove('id');
      return db.insert('despesas_fixas', dados);
    }
    return db.update(
      'despesas_fixas',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deletar(int id) async {
    final db = await _db;
    await db.delete('despesas_fixas', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> gerarPendenciasDoMes(DateTime referencia) async {
    final dataInicio = await AppParametrosService.instance.getDataInicioUso();
    if (dataInicio != null &&
        AppParametrosService.mesReferenciaInteiroAntesDaDataInicio(
          referencia,
          dataInicio,
        )) {
      return 0;
    }

    final db = await _db;
    final anoMes =
        '${referencia.year.toString().padLeft(4, '0')}${referencia.month.toString().padLeft(2, '0')}';

    final fixas = await db.query(
      'despesas_fixas',
      where: 'ativo = 1 AND gerar_automatico = 1',
    );

    int criadas = 0;
    for (final row in fixas) {
      final fixa = DespesaFixa.fromMap(row);
      if (fixa.id == null) continue;

      final grupo = 'FIXA_${fixa.id}_$anoMes';
      final existe = await db.query(
        'conta_pagar',
        columns: ['id'],
        where: 'grupo_parcelas = ?',
        whereArgs: [grupo],
        limit: 1,
      );
      if (existe.isNotEmpty) continue;

      final ultimoDia = DateTime(referencia.year, referencia.month + 1, 0).day;
      final dia = fixa.diaVencimento.clamp(1, ultimoDia);
      final venc = DateTime(referencia.year, referencia.month, dia);

      if (dataInicio != null &&
          AppParametrosService.deveIgnorarVencimento(venc, dataInicio)) {
        continue;
      }

      final conta = ContaPagar(
        descricao: fixa.descricao,
        valor: fixa.valor,
        dataVencimento: venc,
        pago: false,
        grupoParcelas: grupo,
        parcelaNumero: 1,
        parcelaTotal: 1,
        formaPagamento: fixa.formaPagamento,
      );

      final dados = conta.toMap()..remove('id');
      await db.insert('conta_pagar', dados, conflictAlgorithm: ConflictAlgorithm.ignore);
      criadas++;
    }

    return criadas;
  }

  Future<ContaPagar?> getContaDoMesParaFixa({
    required int idDespesaFixa,
    required DateTime referencia,
  }) async {
    final dataInicio = await AppParametrosService.instance.getDataInicioUso();
    if (dataInicio != null &&
        AppParametrosService.mesReferenciaInteiroAntesDaDataInicio(
          referencia,
          dataInicio,
        )) {
      return null;
    }

    final db = await _db;
    final anoMes =
        '${referencia.year.toString().padLeft(4, '0')}${referencia.month.toString().padLeft(2, '0')}';
    final grupo = 'FIXA_${idDespesaFixa}_$anoMes';

    final rows = await db.query(
      'conta_pagar',
      where: 'grupo_parcelas = ?',
      whereArgs: [grupo],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final conta = ContaPagar.fromMap(rows.first);
    if (dataInicio != null &&
        AppParametrosService.deveIgnorarVencimento(
          conta.dataVencimento,
          dataInicio,
        )) {
      return null;
    }
    return conta;
  }

  /// Gera contas do mês (automáticas) e monta resumo de quitado / pendente.
  Future<ResumoDespesasFixasMes> resumoMesAtual() async {
    final ref = DateTime(DateTime.now().year, DateTime.now().month, 1);
    await gerarPendenciasDoMes(ref);
    return resumoMes(ref);
  }

  Future<ResumoDespesasFixasMes> resumoMes(DateTime referencia) async {
    final ref = DateTime(referencia.year, referencia.month, 1);
    final todas = await listar();
    final linhas = <DespesaFixaMesLinha>[];
    double totalPago = 0;
    double totalPendente = 0;

    for (final f in todas) {
      ContaPagar? conta;
      if (f.id != null) {
        conta = await getContaDoMesParaFixa(
          idDespesaFixa: f.id!,
          referencia: ref,
        );
      }
      linhas.add(DespesaFixaMesLinha(fixa: f, conta: conta));
      if (f.ativo && conta != null) {
        if (conta.pago) {
          totalPago += conta.valor;
        } else {
          totalPendente += conta.valor;
        }
      }
    }

    return ResumoDespesasFixasMes(
      mesReferencia: ref,
      linhas: linhas,
      totalPago: totalPago,
      totalPendente: totalPendente,
    );
  }

  /// Despesas fixas automáticas com conta no mês ainda não paga (para aviso na virada).
  Future<List<String>> listarDescricoesNaoPagasNoMes(DateTime referencia) async {
    final ref = DateTime(referencia.year, referencia.month, 1);
    final dataInicio = await AppParametrosService.instance.getDataInicioUso();
    if (dataInicio != null &&
        AppParametrosService.mesReferenciaInteiroAntesDaDataInicio(
          ref,
          dataInicio,
        )) {
      return [];
    }

    await gerarPendenciasDoMes(ref);

    final db = await _db;
    final rows = await db.query(
      'despesas_fixas',
      where: 'ativo = 1 AND gerar_automatico = 1',
    );
    final out = <String>[];
    for (final row in rows) {
      final f = DespesaFixa.fromMap(row);
      if (f.id == null) continue;
      final c = await getContaDoMesParaFixa(
        idDespesaFixa: f.id!,
        referencia: ref,
      );
      if (c != null && !c.pago) {
        out.add(f.descricao);
      }
    }
    return out;
  }
}

