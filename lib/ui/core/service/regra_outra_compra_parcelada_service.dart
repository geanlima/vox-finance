// lib/ui/core/service/regra_outra_compra_parcelada_service.dart

// ignore_for_file: unnecessary_null_comparison

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';

class RegraOutraCompraParceladaService {
  final LancamentoRepository _lancRepo;
  final ContaPagarRepository _contaPagarRepo;

  /// Construtor simples:
  /// - Se não passar nada, ele cria os repositórios padrão
  /// - Se quiser, pode injetar mocks ou repositórios customizados
  RegraOutraCompraParceladaService({
    LancamentoRepository? lancRepo,
    ContaPagarRepository? contaPagarRepo,
  }) : _lancRepo = lancRepo ?? LancamentoRepository(),
       _contaPagarRepo = contaPagarRepo ?? ContaPagarRepository();

  /// Cria as parcelas FUTURAS + contas a pagar,
  /// sempre como NÃO PAGAS
  Future<void> criarParcelasNaoPagas(Lancamento base, int qtdParcelas) async {
    final lancBase = base.copyWith(
      pagamentoFatura: false,
      pago: false,
      dataPagamento: null,
    );

    await _lancRepo.salvarParceladosFuturos(lancBase, qtdParcelas);
  }

  Future<void> marcarLancamentoComoPagoSincronizado(
    Lancamento lanc,
    bool pago,
  ) async {
    if (lanc.id == null) return;

    // 1) Marca o lançamento em si
    await _lancRepo.marcarComoPago(lanc.id!, pago);

    // =====================================================
    // 2) CASO ESPECIAL: FATURA DE CARTÃO
    //    - pagamento_fatura == true
    //    - formaPagamento == crédito
    //    - idCartao preenchido
    //    - dataHora (vencimento) preenchida
    // =====================================================
    final bool ehFaturaCartao =
        lanc.pagamentoFatura == true &&
        lanc.formaPagamento == FormaPagamento.credito &&
        lanc.idCartao != null &&
        lanc.dataHora != null;

    if (ehFaturaCartao) {
      // 2.1) Atualiza a conta_pagar vinculada à fatura
      await _contaPagarRepo.marcarComoPagoPorLancamentoId(lanc.id!, pago);

      // 2.2) Atualiza também a tabela FATURA_CARTAO (opcional mas ideal)
      final cartaoRepo = CartaoCreditoRepository();

      final data = lanc.dataHora!;
      final ano = data.year;
      final mes = data.month;

      await cartaoRepo.salvarFaturaCartao(
        idCartao: lanc.idCartao!, // mesmo cartão do lançamento
        anoReferencia: ano,
        mesReferencia: mes,
        dataFechamento: data, // não é perfeito, mas mantém coerente
        dataVencimento: data,
        valorTotal: lanc.valor, // valor da fatura (já está no lançamento)
        pago: pago,
        dataPagamento: pago ? DateTime.now() : null,
      );

      // Importantíssimo: não cair no fluxo normal de grupo/parcela
      return;
    }

    // =====================================================
    // 3) CASO NORMAL (parcelas, boletos etc.)
    //    Usa grupoParcelas + parcelaNumero para sincronizar
    //    com a tabela conta_pagar
    // =====================================================
    //if (lanc.grupoParcelas != null && lanc.parcelaNumero != null) {
      await _contaPagarRepo.marcarPorGrupoEParcela(
        grupo: lanc.grupoParcelas!,
        parcelaNumero: lanc.parcelaNumero!,
        pago: pago,
      );
    //}
  }
}
