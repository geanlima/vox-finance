// ignore_for_file: unused_field

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/utils/money_split.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/modules/contas_pagar/conta_pagar_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

class IAInterpretacao {
  final double? valor;
  final String? descricao;
  final Categoria? categoria;
  final bool pagamentoFatura;

  IAInterpretacao({
    this.valor,
    this.descricao,
    this.categoria,
    this.pagamentoFatura = false,
  });
}

class IAService {
  final DbService _dbService;
  final ContaPagarRepository _repository = ContaPagarRepository();

  IAService([DbService? dbService]) : _dbService = dbService ?? DbService();

  // ================= INTERPRETAÇÃO ==================

  static IAInterpretacao interpretarTextoLivre(String texto) {
    final lower = texto.toLowerCase();

    final match = RegExp(r'(\d+[.,]?\d*)').firstMatch(lower);
    double? valor;
    if (match != null) {
      var v = match.group(1)!;
      v = v.replaceAll('.', '').replaceAll(',', '.');
      valor = double.tryParse(v);
    }

    var desc = lower;
    if (match != null) {
      desc = desc.replaceFirst(match.group(1)!, '');
    }
    desc =
        desc
            .replaceAll('reais', '')
            .replaceAll('real', '')
            .replaceAll('gastei', '')
            .replaceAll('paguei', '')
            .replaceAll('no débito', '')
            .replaceAll('no credito', '')
            .replaceAll('no crédito', '')
            .replaceAll('no pix', '')
            .replaceAll('pix', '')
            .trim();

    if (desc.isEmpty) {
      desc = 'Sem descrição';
    } else {
      desc = desc[0].toUpperCase() + desc.substring(1);
    }

    final categoria = CategoriaService.fromDescricao(desc);
    final pagamentoFatura = lower.contains('fatura');

    return IAInterpretacao(
      valor: valor,
      descricao: desc,
      categoria: categoria,
      pagamentoFatura: pagamentoFatura,
    );
  }

  // ================= CONTAS A PAGAR ==================

  Future<void> salvarContaSimples({
    required String descricao,
    required double valor,
    required DateTime dataVencimento,
  }) async {
    final cab = DateTime(
      dataVencimento.year,
      dataVencimento.month,
      dataVencimento.day,
    );
    final conta = ContaPagar(
      descricao: descricao,
      valor: valor,
      dataVencimento: dataVencimento,
      pago: false,
      dataPagamento: null,
      parcelaNumero: null,
      parcelaTotal: null,
      grupoParcelas: 'SIMP_${DateTime.now().microsecondsSinceEpoch}',
      dataCabecalho: cab,
    );

    await _repository.salvar(conta);
  }

  Future<void> salvarContasParceladas({
    required String descricao,
    required double valorTotal,
    required DateTime primeiraDataVencimento,
    required int quantidadeParcelas,
  }) async {
    final grupo = 'PARC_${DateTime.now().microsecondsSinceEpoch}';
    final valoresParcela = splitTotalEmPartesIguais(valorTotal, quantidadeParcelas);
    final cab = DateTime(
      primeiraDataVencimento.year,
      primeiraDataVencimento.month,
      primeiraDataVencimento.day,
    );

    for (var i = 0; i < quantidadeParcelas; i++) {
      final venc = DateTime(
        primeiraDataVencimento.year,
        primeiraDataVencimento.month + i,
        primeiraDataVencimento.day,
      );

      final conta = ContaPagar(
        descricao: descricao,
        valor: valoresParcela[i],
        dataVencimento: venc,
        pago: false,
        dataPagamento: null,
        parcelaNumero: i + 1,
        parcelaTotal: quantidadeParcelas,
        grupoParcelas: grupo,
        dataCabecalho: cab,
      );

      await _repository.salvar(conta);
    }
  }
}
