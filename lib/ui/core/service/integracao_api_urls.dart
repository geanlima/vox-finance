/// Monta URLs da API a partir da base configurada em Parâmetros (mesma regra do health).
class IntegracaoApiUrls {
  IntegracaoApiUrls._();

  static String _semBarraFinal(String base) =>
      base.trim().replaceAll(RegExp(r'/+$'), '');

  /// Lista de cartões: `.../api/cartoes` sem duplicar `/api`.
  static Uri cartoes(Uri base) {
    final s = _semBarraFinal(base.toString());
    final u = Uri.parse(s);
    final p = u.path;
    if (p.isEmpty || p == '/') {
      return Uri.parse('${u.origin}/api/cartoes');
    }
    if (p == '/api' || p.endsWith('/api')) {
      return Uri.parse('$s/cartoes');
    }
    return Uri.parse('${u.origin}/api/cartoes');
  }
}
