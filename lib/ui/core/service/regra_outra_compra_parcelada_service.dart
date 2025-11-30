// lib/ui/core/service/regra_outra_compra_parcelada_service.dart

import 'package:vox_finance/ui/data/models/lancamento.dart';
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

  /// Marca lançamento pago + sincroniza conta_pagar (se existir)
  Future<void> marcarLancamentoComoPagoSincronizado(
    Lancamento lanc,
    bool pago,
  ) async {
    if (lanc.id == null) return;

    await _lancRepo.marcarComoPago(lanc.id!, pago);

    if (lanc.grupoParcelas != null && lanc.parcelaNumero != null) {
      await _contaPagarRepo.marcarPorGrupoEParcela(
        grupo: lanc.grupoParcelas!,
        parcelaNumero: lanc.parcelaNumero!,
        pago: pago,
      );
    }
  }
}
