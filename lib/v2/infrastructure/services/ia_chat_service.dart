import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chat com backend FinTrack AI (SSE).
///
/// **Emulador Android:** `10.0.2.2` aponta para o localhost da máquina host.
/// **Celular na mesma rede:** use o IPv4 do PC (ex.: `192.168.1.100`), não use
/// `localhost` no dispositivo físico.
class IaChatService {
  /// Ajuste conforme seu ambiente (ipconfig / ifconfig).
  static const String baseUrl = 'http://10.0.2.2:5000';

  /// Envia mensagem e retorna stream de tokens via SSE.
  Stream<String> enviarMensagem(
    String mensagem,
    List<Map<String, String>> historico,
  ) async* {
    final uri = Uri.parse('$baseUrl/api/Chat');

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

            try {
              final texto = dados.startsWith('"')
                  ? jsonDecode(dados) as String
                  : dados;
              yield texto;
            } catch (_) {
              yield dados;
            }
          }
        }
      }
    } finally {
      client.close();
    }
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
