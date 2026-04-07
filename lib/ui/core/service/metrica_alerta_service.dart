import 'package:vox_finance/ui/core/service/notifications_service.dart';
import 'package:vox_finance/ui/data/models/metrica_limite.dart';
import 'package:vox_finance/ui/data/modules/metricas/metrica_limite_repository.dart';

class AlertaMetricaItem {
  final MetricaLimite metrica;
  final ConsumoMetrica consumo;
  final int nivel; // 1 ou 2

  const AlertaMetricaItem({
    required this.metrica,
    required this.consumo,
    required this.nivel,
  });
}

class MetricaAlertaService {
  final MetricaLimiteRepository _repo;

  const MetricaAlertaService(this._repo);

  String _periodoChave(MetricaLimite m, DateTime ref) {
    if (m.periodoTipo == 'semanal') {
      final sem = m.semana ?? _repo.semanaDoAno(ref);
      return 'semanal_${m.ano}_$sem';
    }
    final mes = m.mes ?? ref.month;
    return 'mensal_${m.ano}_${mes.toString().padLeft(2, '0')}';
  }

  int? _nivelAlerta(MetricaLimite m, double pct) {
    if (pct >= m.alertaPct2) return 2;
    if (pct >= m.alertaPct1) return 1;
    return null;
  }

  Future<List<AlertaMetricaItem>> verificarEAlertar({
    required DateTime agora,
    required void Function(String msg) onHomeMessage,
  }) async {
    // carrega métricas do período atual (mensal + semanal)
    final mensal = await _repo.listarPorPeriodo(
      periodoTipo: 'mensal',
      ano: agora.year,
      mes: agora.month,
      semana: null,
    );
    final semanal = await _repo.listarPorPeriodo(
      periodoTipo: 'semanal',
      ano: agora.year,
      mes: null,
      semana: _repo.semanaDoAno(agora),
    );

    final all = [...mensal, ...semanal].where((m) => m.ativo).toList();
    if (all.isEmpty) return const [];

    await NotificationService.init();

    final alerts = <AlertaMetricaItem>[];

    for (final m in all) {
      if (m.id == null) continue;

      final consumo = await _repo.calcularConsumo(
        metrica: m,
        referenciaPeriodo: agora,
      );

      final nivel = _nivelAlerta(m, consumo.percentual);
      if (nivel == null) continue;

      final chave = _periodoChave(m, agora);
      final ja = await _repo.jaDisparouAlerta(
        metricaId: m.id!,
        periodoChave: chave,
        nivel: nivel,
      );
      if (ja) {
        alerts.add(AlertaMetricaItem(metrica: m, consumo: consumo, nivel: nivel));
        continue;
      }

      final titulo =
          nivel == 2 ? 'Limite atingido' : 'Atenção: perto do limite';
      final body =
          'Você usou ${consumo.percentual.toStringAsFixed(0)}% do limite (R\$ ${consumo.total.toStringAsFixed(2)} de R\$ ${consumo.limite.toStringAsFixed(2)}).';

      // Notificação Android
      await NotificationService.showNow(
        id: (m.id! * 10) + nivel,
        title: titulo,
        body: body,
      );

      // Mensagem na Home (SnackBar)
      onHomeMessage(body);

      await _repo.registrarAlerta(
        metricaId: m.id!,
        periodoChave: chave,
        nivel: nivel,
      );

      alerts.add(AlertaMetricaItem(metrica: m, consumo: consumo, nivel: nivel));
    }

    return alerts;
  }
}

