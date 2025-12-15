// lib/ui/core/regras/regra_cartao_parcelado.dart

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

// lib/ui/core/service/regra_cartao_parcelado_service.dart

class RegraCartaoParceladoService {
  final LancamentoRepository _lancRepo;

  RegraCartaoParceladoService({LancamentoRepository? lancRepo})
    : _lancRepo = lancRepo ?? LancamentoRepository();

  Future<void> processarCompraParcelada({
    required Lancamento compraBase,
    required int qtdParcelas,
  }) async {
    if (compraBase.formaPagamento != FormaPagamento.credito) {
      await _lancRepo.salvar(compraBase);
      return;
    }

    // Buscar cartão para pegar diaVencimento
    CartaoCredito? cartao;
    if (compraBase.idCartao != null) {
      final cartaoRepo = CartaoCreditoRepository();
      cartao = await cartaoRepo.getCartaoCreditoById(compraBase.idCartao!);
    }

    // Se não tem cartão ou não tem diaVencimento, usa fallback
    if (cartao == null || cartao.diaVencimento == null) {
      // Fallback: salva como lançamento simples
      await _lancRepo.salvar(compraBase);
      return;
    }

    final String grupo =
        compraBase.grupoParcelas ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Base para as parcelas - NÃO PAGA
    final Lancamento baseParcelas = compraBase.copyWith(
      id: null,
      grupoParcelas: grupo,
      parcelaNumero: null,
      parcelaTotal: null,
      pagamentoFatura: false,
      pago: compraBase.pago,
      dataPagamento: null,
    );

    // ⭐ CHAMA COM O CARTÃO (para cálculo correto do vencimento)
    await _lancRepo.salvarParceladosFuturos(
      baseParcelas,
      qtdParcelas,
      cartao: cartao, // ⭐ Passa o cartão!
    );
  }
}
