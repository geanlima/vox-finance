enum TipoMensagem { usuario, assistente }

class MensagemChat {
  final String id;
  final TipoMensagem tipo;
  final String conteudo;
  final DateTime timestamp;
  final bool carregando;

  const MensagemChat({
    required this.id,
    required this.tipo,
    required this.conteudo,
    required this.timestamp,
    this.carregando = false,
  });

  MensagemChat copyWith({String? conteudo, bool? carregando}) {
    return MensagemChat(
      id: id,
      tipo: tipo,
      conteudo: conteudo ?? this.conteudo,
      timestamp: timestamp,
      carregando: carregando ?? this.carregando,
    );
  }

  Map<String, String> toHistoricoMap() => {
        'role': tipo == TipoMensagem.usuario ? 'user' : 'assistant',
        'content': conteudo,
      };
}
