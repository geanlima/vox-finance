import 'package:http/http.dart' as http;

/// Resultado do teste de conectividade com a URL base da API.
class ApiAccessTestResult {
  ApiAccessTestResult({
    required this.sucesso,
    required this.mensagem,
    this.statusCode,
    this.urlTestada,
    this.healthStatusCode,
    this.healthUrlTestada,
  });

  final bool sucesso;
  final String mensagem;
  final int? statusCode;
  final String? urlTestada;
  final int? healthStatusCode;
  final String? healthUrlTestada;
}

/// Teste: GET em `/api/health` (URL derivada da base configurada).
class ApiAccessTestService {
  ApiAccessTestService._();
  static final ApiAccessTestService instance = ApiAccessTestService._();

  static const _timeout = Duration(seconds: 15);

  /// Monta `.../api/health` sem gerar `.../api/api/health` quando a base já é `.../api`.
  static Uri healthUriFromBaseInput(String trimmed) {
    final u = Uri.parse(trimmed.replaceAll(RegExp(r'/+$'), ''));
    final p = u.path;
    if (p.isEmpty || p == '/') {
      return u.replace(path: '/api/health');
    }
    if (p == '/api' || p.endsWith('/api')) {
      return u.replace(path: '/api/health');
    }
    return Uri.parse('${u.origin}/api/health');
  }

  Future<ApiAccessTestResult> testarUrlBase(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return ApiAccessTestResult(
        sucesso: false,
        mensagem: 'Informe a URL em Parâmetros.',
      );
    }
    final base = Uri.tryParse(trimmed);
    if (base == null ||
        !base.hasScheme ||
        (base.scheme != 'http' && base.scheme != 'https')) {
      return ApiAccessTestResult(
        sucesso: false,
        mensagem: 'URL inválida. Use http ou https.',
      );
    }

    final semBarraFinal = trimmed.replaceAll(RegExp(r'/+$'), '');
    final healthUri = healthUriFromBaseInput(trimmed);

    int? healthCode;
    Object? healthErro;

    try {
      final r = await http.get(healthUri).timeout(_timeout);
      healthCode = r.statusCode;
    } catch (e) {
      healthErro = e;
    }

    final healthOk =
        healthCode != null && healthCode >= 200 && healthCode < 300;

    final buf = StringBuffer();
    buf.writeln('Health (GET): ${healthUri.toString()}');
    if (healthCode != null) {
      buf.writeln('Status: HTTP $healthCode');
    } else {
      buf.writeln('Falha: ${healthErro ?? 'erro'}');
    }

    return ApiAccessTestResult(
      sucesso: healthOk,
      statusCode: null,
      urlTestada: semBarraFinal,
      healthStatusCode: healthCode,
      healthUrlTestada: healthUri.toString(),
      mensagem: buf.toString().trim(),
    );
  }
}
