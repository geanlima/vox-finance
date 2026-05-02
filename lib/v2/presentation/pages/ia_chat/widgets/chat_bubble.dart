import 'package:flutter/material.dart';

import 'package:vox_finance/v2/presentation/pages/ia_chat/ia_chat_models.dart';

import 'typing_indicator.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.mensagem});

  final MensagemChat mensagem;

  @override
  Widget build(BuildContext context) {
    final ehUsuario = mensagem.tipo == TipoMensagem.usuario;
    final cs = Theme.of(context).colorScheme;
    final bubbleColor = ehUsuario
        ? cs.primary
        : cs.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            ehUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!ehUsuario) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.auto_awesome, size: 14, color: cs.primary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(ehUsuario ? 16 : 4),
                  bottomRight: Radius.circular(ehUsuario ? 4 : 16),
                ),
              ),
              child: mensagem.carregando && mensagem.conteudo.isEmpty
                  ? const TypingIndicator()
                  : SelectableText(
                      mensagem.conteudo,
                      style: TextStyle(
                        color: ehUsuario
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (ehUsuario) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
