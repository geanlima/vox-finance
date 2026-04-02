import 'package:vox_finance/ui/data/modules/despesas_fixas/despesa_fixa_repository.dart';

class DespesasFixasService {
  final DespesaFixaRepository _repo;
  DespesasFixasService({DespesaFixaRepository? repo})
    : _repo = repo ?? DespesaFixaRepository();

  Future<int> gerarNoMesAtualSeNecessario() async {
    final hoje = DateTime.now();
    final mesAtual = DateTime(hoje.year, hoje.month, 1);
    return _repo.gerarPendenciasDoMes(mesAtual);
  }
}

