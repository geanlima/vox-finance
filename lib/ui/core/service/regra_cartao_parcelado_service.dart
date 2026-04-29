// lib/ui/core/service/regra_cartao_parcelado_service.dart

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

/// Regra para gravar compra **parcelada** no cartão de crédito.
///
/// Não exige mais `dia_vencimento` só no cadastro do cartão: o ciclo pode vir
/// do calendário mensal (`cartao_credito_calendario`). O repositório já trata
/// vencimento com fallback quando não há ciclo.
class RegraCartaoParceladoService {
  final LancamentoRepository _lancRepo;
  final CartaoCreditoRepository _cartaoRepo;

  RegraCartaoParceladoService({
    LancamentoRepository? lancRepo,
    CartaoCreditoRepository? cartaoRepo,
  })  : _lancRepo = lancRepo ?? LancamentoRepository(),
        _cartaoRepo = cartaoRepo ?? CartaoCreditoRepository();

  Future<void> processarCompraParcelada({
    required Lancamento compraBase,
    required int qtdParcelas,
  }) async {
    if (compraBase.formaPagamento != FormaPagamento.credito) {
      await _lancRepo.salvar(compraBase);
      return;
    }

    final idCartao = compraBase.idCartao;
    if (idCartao == null) {
      await _lancRepo.salvar(compraBase);
      return;
    }

    if (await _cartaoRepo.getCartaoCreditoById(idCartao) == null) {
      await _lancRepo.salvar(compraBase);
      return;
    }

    final g = compraBase.grupoParcelas?.trim();
    final String grupo = (g != null && g.isNotEmpty)
        ? g
        : DateTime.now().millisecondsSinceEpoch.toString();

    // Compras no cartão não são "contas a pagar". Quem fica pendente é a fatura.
    // Então preserva o status de pagamento da base (normalmente "pago=true").
    final bool pagoParcelamento = compraBase.pago;
    final DateTime? dataPagParcelamento = pagoParcelamento
        ? (compraBase.dataPagamento ?? DateTime.now())
        : null;

    final Lancamento baseParcelas = compraBase.copyWith(
      id: null,
      grupoParcelas: grupo,
      parcelaNumero: null,
      parcelaTotal: null,
      pagamentoFatura: false,
      pago: pagoParcelamento,
      dataPagamento: dataPagParcelamento,
    );

    await _lancRepo.salvarParceladosFuturos(baseParcelas, qtdParcelas);
  }
}
