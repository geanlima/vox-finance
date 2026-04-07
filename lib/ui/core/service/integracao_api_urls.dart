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

  /// Valor de `competencia` na query: `MM/YYYY` (ex.: `02/2026`).
  static String competenciaMmYyyy(int ano, int mes) =>
      '${mes.toString().padLeft(2, '0')}/${ano.toString().padLeft(4, '0')}';

  /// Lista faturas (Swagger): `GET .../api/faturas?cartao_id=&competencia=`
  /// [competencia] no formato [competenciaMmYyyy].
  static Uri faturas(Uri base, {required String cartaoId, required String competencia}) {
    final s = _semBarraFinal(base.toString());
    final u = Uri.parse(s);
    final p = u.path;
    final q = {'cartao_id': cartaoId, 'competencia': competencia};
    if (p.isEmpty || p == '/') {
      return Uri.parse('${u.origin}/api/faturas').replace(queryParameters: q);
    }
    if (p == '/api' || p.endsWith('/api')) {
      return Uri.parse('$s/faturas').replace(queryParameters: q);
    }
    return Uri.parse('${u.origin}/api/faturas').replace(queryParameters: q);
  }
}
