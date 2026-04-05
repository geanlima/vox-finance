import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vox_finance/ui/data/modules/despesas_fixas/despesa_fixa_repository.dart';

/// Aviso único por mês: ao entrar no mês atual, alerta se no mês anterior
/// havia despesa fixa automática não paga.
class DespesasFixasAvisoService {
  DespesasFixasAvisoService._();

  static const _kUltimoMesAviso = 'despesa_fixa_aviso_virada_mes';

  static Future<void> tentarMostrarAvisoMesAnteriorSeNecessario(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final agora = DateTime.now();
    final chaveMesAtual =
        '${agora.year}-${agora.month.toString().padLeft(2, '0')}';

    if (prefs.getString(_kUltimoMesAviso) == chaveMesAtual) {
      return;
    }

    final mesAnterior = DateTime(agora.year, agora.month - 1, 1);
    final repo = DespesaFixaRepository();
    final pendentes = await repo.listarDescricoesNaoPagasNoMes(mesAnterior);

    await prefs.setString(_kUltimoMesAviso, chaveMesAtual);

    if (pendentes.isEmpty || !context.mounted) {
      return;
    }

    final mesNome = _mesAnoPt(mesAnterior);
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Despesas fixas do mês anterior'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Em $mesNome ficou pendente o pagamento de:',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...pendentes.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(e)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  static String _mesAnoPt(DateTime d) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${meses[d.month - 1]} de ${d.year}';
  }
}
