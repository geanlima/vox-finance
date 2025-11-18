enum GraficoVisaoInicial { ano, mes, dia }

extension GraficoVisaoInicialExt on GraficoVisaoInicial {
  String get label {
    switch (this) {
      case GraficoVisaoInicial.ano:
        return "Visão por Ano";
      case GraficoVisaoInicial.mes:
        return "Visão por Mês";
      case GraficoVisaoInicial.dia:
        return "Visão por Dia";
    }
  }
}
