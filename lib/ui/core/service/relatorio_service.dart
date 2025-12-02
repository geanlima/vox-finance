// lib/ui/core/service/relatorio_service.dart
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class MesValor {
  final int mes;
  final double total;
  MesValor(this.mes, this.total);
}

class RelatorioService {
  final LancamentoRepository _repo;
  RelatorioService({LancamentoRepository? repo})
      : _repo = repo ?? LancamentoRepository();

  Future<List<MesValor>> totaisPorMes(int ano) async {
    final inicio = DateTime(ano, 1, 1);
    final fim = DateTime(ano, 12, 31, 23, 59, 59);

    final dados = await _repo.getByPeriodo(inicio, fim);
    final Map<int, double> meses = {for (var m = 1; m <= 12; m++) m: 0.0};

    for (final l in dados) {
      if (!l.pago) continue;
      meses[l.dataHora.month] = meses[l.dataHora.month]! + l.valor;
    }

    return meses.entries.map((e) => MesValor(e.key, e.value)).toList();
  }

  Future<Map<String, double>> totaisPorCategoria(DateTime mes) async {
    final inicio = DateTime(mes.year, mes.month, 1);
    final fim =
        DateTime(mes.year, mes.month + 1, 1).subtract(const Duration(seconds: 1));

    final dados = await _repo.getByPeriodo(inicio, fim);
    final Map<String, double> mapa = {};

    for (final l in dados) {
      if (!l.pago) continue;
      final nome = CategoriaService.toName(l.categoria);
      mapa.update(nome, (v) => v + l.valor, ifAbsent: () => l.valor);
    }

    return mapa;
  }

  Future<Map<String, int>> histograma(DateTime mes) async {
    final inicio = DateTime(mes.year, mes.month, 1);
    final fim =
        DateTime(mes.year, mes.month + 1, 1).subtract(const Duration(seconds: 1));

    final dados = await _repo.getByPeriodo(inicio, fim);
    final Map<String, int> faixas = {
      '0–50': 0,
      '50–100': 0,
      '100–200': 0,
      '200–400': 0,
      '400+': 0,
    };

    for (final l in dados) {
      if (!l.pago) continue;
      final v = l.valor;

      if (v < 50) {
        faixas['0–50'] = faixas['0–50']! + 1;
      } else if (v < 100) {
        faixas['50–100'] = faixas['50–100']! + 1;
      } else if (v < 200) {
        faixas['100–200'] = faixas['100–200']! + 1;
      } else if (v < 400) {
        faixas['200–400'] = faixas['200–400']! + 1;
      } else {
        faixas['400+'] = faixas['400+']! + 1;
      }
    }

    return faixas;
  }
}
