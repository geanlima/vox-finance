enum TipoGrafico { linha, barra, pizza, histograma }

extension TipoGraficoExt on TipoGrafico {
  String get label {
    switch (this) {
      case TipoGrafico.linha:
        return 'Linha';
      case TipoGrafico.barra:
        return 'Barras';
      case TipoGrafico.pizza:
        return 'Pizza';
      case TipoGrafico.histograma:
        return 'Histograma';
    }
  }

  String get key {
    // usado pra salvar nas preferencias
    return toString().split('.').last;
  }

  static TipoGrafico fromKey(String key) {
    return TipoGrafico.values.firstWhere(
      (e) => e.key == key,
      orElse: () => TipoGrafico.barra,
    );
  }
}
