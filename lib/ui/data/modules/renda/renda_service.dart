import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/models/fonte_renda.dart';
import 'package:vox_finance/ui/data/modules/renda/renda_repository.dart';

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
  final RendaRepository _rendaRepo;

  RendaService({LancamentoRepository? lancRepo, RendaRepository? rendaRepo})
    : _lancRepo = lancRepo ?? LancamentoRepository(),
      _rendaRepo = rendaRepo ?? RendaRepository();

  /// ============================
  /// RESUMO MENSAL (já existia)
  /// ============================
  /// Retorna o resumo de RECEITAS do mês (apenas tipoMovimento == receita)
  Future<RendaResumoMes> calcularResumoMes(DateTime referencia) async {
    final inicio = DateTime(referencia.year, referencia.month, 1);
    final fim = DateTime(
      referencia.year,
      referencia.month + 1,
      1,
    ).subtract(const Duration(milliseconds: 1));

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

  /// ============================
  /// NOVO: Renda diária das fontes
  /// ============================
  /// Soma a parte DIÁRIA das fontes de renda marcadas com
  /// incluirNaRendaDiaria = true e ativas.
  ///
  /// Exemplo: Salário 3000, mês com 30 dias => 100/dia.
  Future<double> calcularRendaDiariaBaseadaNasFontes(DateTime dia) async {
    // pega todas as fontes (ou só ativas, se quiser)
    final List<FonteRenda> fontes = await _rendaRepo.listarFontes(
      apenasAtivas: true,
    );

    final fontesParaDiario =
        fontes.where((f) => f.incluirNaRendaDiaria == true).toList();

    if (fontesParaDiario.isEmpty) return 0.0;

    final diasMes = DateTime(dia.year, dia.month + 1, 0).day;

    final totalRendaDiaria = fontesParaDiario.fold<double>(
      0.0,
      (soma, f) => soma + (f.valorBase / diasMes),
    );

    return totalRendaDiaria;
  }

  /// ============================
  /// NOVO: Total de receitas do dia
  /// ============================
  /// Total de receitas do dia = receitas de lançamentos do dia
  /// + renda diária (fontes marcadas).
  Future<double> calcularTotalReceitasDiaComRenda(DateTime dia) async {
    // 1) receitas dos lançamentos do dia
    final inicio = DateTime(dia.year, dia.month, dia.day, 0, 0, 0);
    final fim = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);

    final List<Lancamento> todos = await _lancRepo.getByPeriodo(inicio, fim);

    final receitasDoDia = todos.where(
      (l) => l.tipoMovimento == TipoMovimento.receita,
    );

    final totalReceitasLancamentos = receitasDoDia.fold<double>(
      0.0,
      (soma, l) => soma + l.valor,
    );

    // 2) renda diária baseada nas fontes
    final rendaDiaria = await calcularRendaDiariaBaseadaNasFontes(dia);

    // 3) soma tudo
    return totalReceitasLancamentos + rendaDiaria;
  }
}
