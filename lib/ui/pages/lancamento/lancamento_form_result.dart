import 'package:vox_finance/ui/data/models/lancamento.dart';

class LancamentoFormResult {
  final Lancamento lancamentoBase;
  final int qtdParcelas;

  LancamentoFormResult({
    required this.lancamentoBase,
    required this.qtdParcelas,
  });
}
