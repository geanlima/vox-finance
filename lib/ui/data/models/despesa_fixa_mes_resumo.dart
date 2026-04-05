import 'package:vox_finance/ui/data/models/conta_pagar.dart';
import 'package:vox_finance/ui/data/models/despesa_fixa.dart';

/// Situação da despesa fixa em um mês de referência (conta FIXA_* no `conta_pagar`).
enum DespesaFixaSituacaoMes {
  /// Tem conta no mês e está paga.
  quitado,

  /// Tem conta no mês e ainda não paga.
  pendente,

  /// Não há conta gerada para o mês (ex.: manual sem lançamento).
  semLancamento,

  /// Cadastro inativo (não entra nos totais do mês).
  inativa,
}

class DespesaFixaMesLinha {
  final DespesaFixa fixa;
  final ContaPagar? conta;

  const DespesaFixaMesLinha({required this.fixa, this.conta});

  DespesaFixaSituacaoMes get situacao {
    if (!fixa.ativo) {
      return DespesaFixaSituacaoMes.inativa;
    }
    if (conta == null) return DespesaFixaSituacaoMes.semLancamento;
    if (conta!.pago) return DespesaFixaSituacaoMes.quitado;
    return DespesaFixaSituacaoMes.pendente;
  }

  /// Valor exibido para o mês (conta ou cadastro).
  double get valorReferencia => conta?.valor ?? fixa.valor;
}

class ResumoDespesasFixasMes {
  final DateTime mesReferencia;
  final List<DespesaFixaMesLinha> linhas;
  final double totalPago;
  final double totalPendente;

  const ResumoDespesasFixasMes({
    required this.mesReferencia,
    required this.linhas,
    required this.totalPago,
    required this.totalPendente,
  });

  double get totalMes => totalPago + totalPendente;
}
