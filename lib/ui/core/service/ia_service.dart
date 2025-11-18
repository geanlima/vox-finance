import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/core/service/categorias_service.dart';
import 'package:vox_finance/ui/data/sevice/isar_service.dart';

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
  final IsarService _isarService;

  // 👇 aceita o IsarService, mas é opcional (se não passar, cria um novo)
  IAService([IsarService? isarService])
    : _isarService = isarService ?? IsarService();

  // ============================================================
  //  INTERPRETAÇÃO DE TEXTO LIVRE (VOZ / OCR)
  // ============================================================

  static IAInterpretacao interpretarTextoLivre(String texto) {
    final lower = texto.toLowerCase();

    // Valor (primeiro número do texto)
    final match = RegExp(r'(\d+[.,]?\d*)').firstMatch(lower);
    double? valor;
    if (match != null) {
      var v = match.group(1)!;
      v = v.replaceAll('.', '').replaceAll(',', '.');
      valor = double.tryParse(v);
    }

    // Descrição
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

  // ============================================================
  //  CONTAS A PAGAR – CRIAÇÃO DE REGISTROS
  // ============================================================

  /// Conta simples (sem parcelamento)
  Future<void> salvarContaSimples({
    required String descricao,
    required double valor,
    required DateTime dataVencimento,
  }) async {
    final isar = await _isarService.db;

    final conta =
        ContaPagar()
          ..descricao = descricao
          ..valor = valor
          ..dataVencimento = dataVencimento
          ..pago = false
          ..dataPagamento = null
          ..parcelaNumero = null
          ..parcelaTotal = null
          ..grupoParcelas =
              'SIMP_${DateTime.now().microsecondsSinceEpoch.toString()}';

    await isar.writeTxn(() async {
      await isar.contaPagars.put(conta);
    });
  }

  /// Cria várias parcelas de uma compra (ex: 10x)
  Future<void> salvarContasParceladas({
    required String descricao,
    required double valorTotal,
    required DateTime primeiraDataVencimento,
    required int quantidadeParcelas,
  }) async {
    final isar = await _isarService.db;

    final grupo = 'PARC_${DateTime.now().microsecondsSinceEpoch.toString()}';
    final valorParcela = valorTotal / quantidadeParcelas;

    await isar.writeTxn(() async {
      for (var i = 0; i < quantidadeParcelas; i++) {
        final venc = DateTime(
          primeiraDataVencimento.year,
          primeiraDataVencimento.month + i,
          primeiraDataVencimento.day,
        );

        final conta =
            ContaPagar()
              ..descricao = descricao
              ..valor = valorParcela
              ..dataVencimento = venc
              ..pago = false
              ..dataPagamento = null
              ..parcelaNumero = i + 1
              ..parcelaTotal = quantidadeParcelas
              ..grupoParcelas = grupo;

        await isar.contaPagars.put(conta);
      }
    });
  }
}
