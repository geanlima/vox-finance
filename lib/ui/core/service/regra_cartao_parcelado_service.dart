// lib/ui/core/regras/regra_cartao_parcelado.dart
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class RegraCartaoParceladoService {
  final DbService _db;

  RegraCartaoParceladoService(this._db);

  /// Regra 1 - Cartão de crédito parcelado
  ///
  /// - compraBase: lançamento que o usuário preencheu na tela
  /// - qtdParcelas: quantidade de parcelas (ex.: 5)
  ///
  /// Comportamento:
  /// 1) Se for cartão, marca a compra como PAGA no dia da compra
  /// 2) Gera as parcelas futuras (lancamentos + contas a pagar)
  Future<void> processarCompraParcelada({
    required Lancamento compraBase,
    required int qtdParcelas,
  }) async {
    // Segurança: essa regra só faz sentido para cartão de crédito
    if (compraBase.formaPagamento != FormaPagamento.credito) {
      // se quiser, pode apenas salvar normal aqui
      await _db.salvarLancamento(compraBase);
      return;
    }

    final agora = DateTime.now();

    // 1) A compra no cartão é considerada "paga" no dia da compra
    final Lancamento compraAjustada = compraBase.copyWith(
      pagamentoFatura: false,              // não é fatura ainda
      pago: true,                          // compra já "paga" (usou o cartão)
      dataPagamento: compraBase.dataPagamento ?? agora,
      // grupoParcelas ainda pode ser nulo aqui; será definido ao gerar as parcelas
    );

    // Salva OU atualiza esse lançamento principal (o da compra)
    final idCompra = await _db.salvarLancamento(compraAjustada);

    // Garante que o objeto tenha o id preenchido
    final compraComId = compraAjustada.copyWith(id: idCompra);

    // 2) Gera as parcelas futuras + contas a pagar amarradas
    //
    // Essa função do DbService já está preparada para:
    //  - criar N lançamentos futuros (parcelas)
    //  - criar N registros em conta_pagar
    //  - amarrar tudo via grupo_parcelas + id_cartao/id_conta/forma_pagamento
    await _db.salvarLancamentosParceladosFuturos(
      compraComId,
      qtdParcelas,
    );
  }
}
