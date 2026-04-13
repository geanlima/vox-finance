/// `true` se os valores coincidem em centavos ou diferem no máximo 1 centavo
/// (ex.: 135,04 no extrato vs 135,05 no app).
bool coincideValorAssociacao(double a, double b) {
  return ((a * 100).round() - (b * 100).round()).abs() <= 1;
}

/// Divide [valorTotal] em [n] partes cuja soma em centavos coincide com o total
/// arredondado (evita perda de centavos por `valorTotal / n` em double).
List<double> splitTotalEmPartesIguais(double valorTotal, int n) {
  if (n <= 0) return const [];
  final totalCentavos = (valorTotal * 100).round();
  final base = totalCentavos ~/ n;
  final resto = totalCentavos % n;
  return List<double>.generate(n, (i) {
    final centavos = base + (i < resto ? 1 : 0);
    return centavos / 100.0;
  });
}
