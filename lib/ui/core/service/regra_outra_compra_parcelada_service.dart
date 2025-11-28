// lib/ui/core/service/regra_outra_compra_parcelada_service.dart
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class RegraOutraCompraParceladaService {
  final DbService _db;

  RegraOutraCompraParceladaService(this._db);

  /// Cria as parcelas FUTURAS + contas a pagar,
  /// sempre como NÃO PAGAS (fluxo: boleto, pix, débito, etc.)
  Future<void> criarParcelasNaoPagas(Lancamento base, int qtdParcelas) async {
    // Garante que NÃO é fatura de cartão
    final lancBase = base.copyWith(
      pagamentoFatura: false,
      // para "outra compra parcelada", normalmente começa não pago
      pago: false,
      dataPagamento: null,
      // se não for cartão, em geral idCartao é null
      // mas mesmo que venha preenchido, essa regra é pensada
      // para os casos "fora do cartão"
    );

    await _db.salvarLancamentosParceladosFuturos(lancBase, qtdParcelas);
  }

  /// Quando o usuário marcar um lançamento como pago na tela de lançamentos,
  /// sincroniza também a CONTA A PAGAR vinculada (se houver).
  Future<void> marcarLancamentoComoPagoSincronizado(
    Lancamento lanc,
    bool pago,
  ) async {
    if (lanc.id == null) return;

    // 1) Atualiza o lançamento normalmente
    await _db.marcarLancamentoComoPago(lanc.id!, pago);

    // 2) Se tiver grupo/parcela, atualiza a conta_pagar correspondente
    if (lanc.grupoParcelas != null && lanc.parcelaNumero != null) {
      final database = await _db.db;

      final agora = DateTime.now();
      final agoraMs = agora.millisecondsSinceEpoch;

      await database.update(
        'conta_pagar',
        {'pago': pago ? 1 : 0, 'data_pagamento': pago ? agoraMs : null},
        where: 'grupo_parcelas = ? AND parcela_numero = ?',
        whereArgs: [lanc.grupoParcelas, lanc.parcelaNumero],
      );
    }
  }
}
