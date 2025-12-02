// lib/ui/core/regras/regra_cartao_parcelado.dart

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class RegraCartaoParceladoService {
  final LancamentoRepository _lancRepo;

  /// Mesmo padrão da RegraOutraCompraParceladaService:
  /// - se não passar nada, cria o repo padrão
  /// - se quiser, pode injetar um mock / customizado
  RegraCartaoParceladoService({LancamentoRepository? lancRepo})
    : _lancRepo = lancRepo ?? LancamentoRepository();

  /// Regra 1 - Cartão de crédito parcelado
  ///
  /// - compraBase: lançamento que o usuário preencheu na tela
  /// - qtdParcelas: quantidade de parcelas (ex.: 5)
  ///
  /// Comportamento:
  /// 1) Se for cartão, marca a compra como PAGA no dia da compra
  /// 2) Gera as parcelas futuras (lancamentos + contas a pagar) como NÃO PAGAS
  Future<void> processarCompraParcelada({
    required Lancamento compraBase,
    required int qtdParcelas,
  }) async {
    // Segurança: essa regra só faz sentido para cartão de crédito
    if (compraBase.formaPagamento != FormaPagamento.credito) {
      // fallback: salva normal se não for crédito
      await _lancRepo.salvar(compraBase);
      return;
    }

    // Um grupo único para todas as parcelas
    final String grupo =
        compraBase.grupoParcelas ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Base para as parcelas:
    //  - NÃO vamos salvar um lançamento "total"
    //  - só criaremos as parcelas (cada uma com valor dividido)
    final Lancamento baseParcelas = compraBase.copyWith(
      id: null, // garante insert novo
      grupoParcelas: grupo, // mesmo grupo em todas as parcelas
      parcelaNumero: null, // a função salvarParceladosFuturos preenche
      parcelaTotal: null, // idem
      pagamentoFatura: false, // ainda não é pagamento de fatura
      pago: true, // parcelas começam em aberto
      dataPagamento: null,
    );

    // Vai criar:
    //  - N lançamentos futuros com valor da parcela
    //  - N contas a pagar ligadas ao mesmo grupo
    await _lancRepo.salvarParceladosFuturos(baseParcelas, qtdParcelas);
  }
}
