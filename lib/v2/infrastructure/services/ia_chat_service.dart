import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chat com backend FinTrack AI (SSE).
///
/// A URL base é configurada em **Parâmetros → FinTrack IA** e passada em [apiBaseUrl].
class IaChatService {
  /// Envia mensagem e retorna stream de tokens via SSE.
  ///
  /// [apiBaseUrl] URL sem path (ex.: `https://fintrackai-backend.azurewebsites.net`).
  Stream<String> enviarMensagem(
    String mensagem,
    List<Map<String, String>> historico, {
    required String apiBaseUrl,
  }) async* {
    final base = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/Chat');

    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'mensagem': mensagem,
      'historico': historico,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IaChatRequestException(
          'HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      var buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        var idx = buffer.indexOf('\n');
        while (idx >= 0) {
          final line = buffer.substring(0, idx).trimRight();
          buffer = buffer.substring(idx + 1);
          idx = buffer.indexOf('\n');

          if (line.startsWith('data: ')) {
            final dados = line.substring(6).trim();

            if (dados == '[DONE]') return;
            if (dados.isEmpty) continue;

            final texto = _textoDoPayloadSse(dados);
            if (texto != null && texto.isNotEmpty) {
              yield texto;
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Converte `data:` do SSE em texto para o chat.
  ///
  /// O backend pode enviar:
  /// - string JSON (`"olá"`),
  /// - objeto `{"tipo":"token"|"agente","conteudo":"..."}` (só [token] vira texto),
  /// - texto puro (compatível com outros backends).
  static String? _textoDoPayloadSse(String dados) {
    if (dados.startsWith('"')) {
      try {
        final v = jsonDecode(dados);
        if (v is String) return v;
      } catch (_) {}
    }
    if (dados.startsWith('{')) {
      try {
        final v = jsonDecode(dados);
        if (v is! Map) return null;
        final m = Map<String, dynamic>.from(v);
        final tipo = m['tipo']?.toString().toLowerCase();
        final conteudo = m['conteudo'];
        if (conteudo == null) return null;
        final s = conteudo.toString();
        if (tipo == 'agente') return null;
        if (tipo == 'token' || tipo == null) return s;
        return null;
      } catch (_) {
        return null;
      }
    }
    return dados;
  }
}

class IaChatRequestException implements Exception {
  IaChatRequestException(this.message, {this.uri});
  final String message;
  final Uri? uri;

  @override
  String toString() => uri != null
      ? 'IaChatRequestException: $message ($uri)'
      : 'IaChatRequestException: $message';
}
