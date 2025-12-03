import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class RendaResumoMes {
  final double totalRecebido;
  final double totalPrevisto;

  const RendaResumoMes({
    required this.totalRecebido,
    required this.totalPrevisto,
  });

  double get totalMes => totalRecebido + totalPrevisto;
}

class RendaService {
  final LancamentoRepository _lancRepo;

  RendaService({LancamentoRepository? lancRepo})
    : _lancRepo = lancRepo ?? LancamentoRepository();

  /// Retorna o resumo de RECEITAS do mês (apenas tipoMovimento == receita)
  Future<RendaResumoMes> calcularResumoMes(DateTime referencia) async {
    final inicio = DateTime(referencia.year, referencia.month, 1);
    final fim = DateTime(
      referencia.year,
      referencia.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

    // Se você ainda não tiver esse método, depois a gente implementa.
    final List<Lancamento> todos = await _lancRepo.getByPeriodo(inicio, fim);

    final receitas = todos.where(
      (l) => l.tipoMovimento == TipoMovimento.receita,
    );

    final recebidas = receitas.where((l) => l.pago == true).toList();
    final pendentes = receitas.where((l) => l.pago != true).toList();

    final totalRecebido = recebidas.fold<double>(
      0.0,
      (soma, l) => soma + l.valor,
    );
    final totalPrevisto = pendentes.fold<double>(
      0.0,
      (soma, l) => soma + l.valor,
    );

    return RendaResumoMes(
      totalRecebido: totalRecebido,
      totalPrevisto: totalPrevisto,
    );
  }
}
