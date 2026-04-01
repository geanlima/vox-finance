import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/extensions/list_extensions.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class ContaPagarPagamentoService {
  final DbService _db;
  final ContaPagarRepository _contaRepo;
  final LancamentoRepository _lancRepo;
  final CategoriaPersonalizadaRepository _catPersRepo;

  ContaPagarPagamentoService({
    DbService? db,
    ContaPagarRepository? contaRepo,
    LancamentoRepository? lancRepo,
    CategoriaPersonalizadaRepository? catPersRepo,
  }) : _db = db ?? DbService(),
       _contaRepo = contaRepo ?? ContaPagarRepository(),
       _lancRepo = lancRepo ?? LancamentoRepository(),
       _catPersRepo = catPersRepo ?? CategoriaPersonalizadaRepository();

  Future<void> registrarPagamento(
    ContaPagar parcela, {
    DateTime? dataPagamento,
  }) async {
    final agora = dataPagamento ?? DateTime.now();

    // 0) Cartão de crédito → só marca conta a pagar como paga
    final bool ehCartao =
        parcela.formaPagamento == FormaPagamento.credito &&
        parcela.idCartao != null;

    if (ehCartao) {
      if (parcela.id != null) {
        await _contaRepo.marcarParcelaComoPaga(parcela.id!, true);
      }
      return;
    }

    // 1) Localizar lançamento FUTURO associado
    Lancamento? lancamentoOriginal;

    final lancamentosDoGrupo = await _lancRepo.getParcelasPorGrupo(
      parcela.grupoParcelas,
    );

    lancamentoOriginal = lancamentosDoGrupo.firstWhereOrNull(
      (l) => (l.parcelaNumero ?? 1) == (parcela.parcelaNumero ?? 1),
    );

    // fallback caso não ache pelo grupo
    if (lancamentoOriginal == null) {
      final database = await _db.db;
      final result = await database.query(
        'lancamentos',
        where: 'data_hora = ? AND valor = ? AND descricao = ?',
        whereArgs: [
          parcela.dataVencimento.millisecondsSinceEpoch,
          parcela.valor,
          parcela.descricao,
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        lancamentoOriginal = Lancamento.fromMap(result.first);
      }
    }

    // 2) Apagar lançamento FUTURO original
    if (lancamentoOriginal != null && lancamentoOriginal.id != null) {
      await _lancRepo.deletar(lancamentoOriginal.id!);
    }

    // 3) Categoria/flags para despesas fixas (geradas)
    final bool ehDespesaFixa = parcela.grupoParcelas.startsWith('FIXA_');
    final catDespesaFixa =
        ehDespesaFixa
            ? await _catPersRepo.getOrCreate(
              nome: 'Despesas fixas',
              tipoMovimento: TipoMovimento.despesa,
            )
            : null;

    // 4) Criar novo lançamento PAGO NA DATA ATUAL
    final novoLancamento = Lancamento(
      id: null,
      valor: parcela.valor,
      descricao:
          'Parcela ${parcela.parcelaNumero}/${parcela.parcelaTotal} - ${parcela.descricao}',
      formaPagamento: parcela.formaPagamento ?? FormaPagamento.debito,
      dataHora: agora,
      pagamentoFatura: false,
      pago: true,
      dataPagamento: agora,
      categoria: lancamentoOriginal?.categoria ?? Categoria.outros,
      idCategoriaPersonalizada:
          catDespesaFixa?.id ?? lancamentoOriginal?.idCategoriaPersonalizada,
      tipoDespesa:
          ehDespesaFixa
              ? TipoDespesa.fixa
              : (lancamentoOriginal?.tipoDespesa ?? TipoDespesa.variavel),
      idCartao: parcela.idCartao,
      idConta: parcela.idConta,
      grupoParcelas: parcela.grupoParcelas,
      parcelaNumero: parcela.parcelaNumero,
      parcelaTotal: parcela.parcelaTotal,
    );

    await _lancRepo.salvar(novoLancamento);

    // 5) Marcar conta a pagar como paga
    if (parcela.id != null) {
      await _contaRepo.marcarParcelaComoPaga(parcela.id!, true);
    }
  }
}

