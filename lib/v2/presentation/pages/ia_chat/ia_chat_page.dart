// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/v2/infrastructure/services/ia_chat_service.dart';
import 'package:vox_finance/v2/presentation/pages/ia_chat/ia_chat_models.dart';
import 'package:vox_finance/v2/presentation/pages/ia_chat/widgets/chat_bubble.dart';
import 'package:vox_finance/v2/presentation/pages/ia_chat/widgets/chat_input.dart';
import 'package:vox_finance/v2/widgets/v2_drawer.dart';

class IaChatPage extends StatefulWidget {
  const IaChatPage({super.key, this.drawer});

  /// Rota canônica (V1 e V2).
  static const routeName = '/ia-chat';

  /// Drawer da shell atual. Se `null`, usa [V2Drawer] (fluxo V2 isolado).
  final Widget? drawer;

  @override
  State<IaChatPage> createState() => _IaChatPageState();
}

class _IaChatPageState extends State<IaChatPage> {
  final IaChatService _service = IaChatService();
  final List<MensagemChat> _mensagens = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _enviando = false;
  StreamSubscription<String>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _limparConversa() {
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _mensagens.clear();
      _enviando = false;
    });
  }

  Widget _buildListaMensagens() {
    if (_mensagens.isEmpty) {
      return const Center(
        child: Text('Comece uma conversa com a FinTrack IA.'),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _mensagens.length,
      itemBuilder: (context, i) {
        return ChatBubble(mensagem: _mensagens[i]);
      },
    );
  }

  Widget _buildSugestoes() {
    final sugestoes = [
      '💰 Quanto gastei esse mês?',
      '📊 Quais minhas maiores despesas?',
      '💳 Tenho contas pendentes?',
      '📈 Como está meu saldo?',
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sugestões:',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                sugestoes.map((s) {
                  return ActionChip(
                    label: Text(s),
                    onPressed:
                        _enviando
                            ? null
                            : () {
                              _controller.text = s.replaceAll(
                                RegExp(r'^[^\s]+\s*'),
                                '',
                              );
                              _enviarMensagem();
                            },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarMensagem() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    await _subscription?.cancel();
    _subscription = null;

    setState(() {
      _enviando = true;
      _controller.clear();

      _mensagens.add(
        MensagemChat(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          tipo: TipoMensagem.usuario,
          conteudo: texto,
          timestamp: DateTime.now(),
        ),
      );

      _mensagens.add(
        MensagemChat(
          id: 'loading',
          tipo: TipoMensagem.assistente,
          conteudo: '',
          timestamp: DateTime.now(),
          carregando: true,
        ),
      );
    });

    _scrollToBottom();

    final historico =
        _mensagens
            .where((m) => !m.carregando && m.conteudo.isNotEmpty)
            .map((m) => m.toHistoricoMap())
            .toList();

    var respostaAcumulada = '';
    var streamFinalizado = false;

    void finalizarComErro(String mensagemErro) {
      if (streamFinalizado || !mounted) return;
      streamFinalizado = true;
      setState(() {
        final idx = _mensagens.indexWhere((m) => m.id == 'loading');
        if (idx >= 0) {
          _mensagens[idx] = _mensagens[idx].copyWith(
            conteudo: mensagemErro,
            carregando: false,
          );
        }
        _enviando = false;
      });
      _subscription = null;
      _scrollToBottom();
    }

    void finalizarComSucesso() {
      if (streamFinalizado || !mounted) return;
      streamFinalizado = true;
      setState(() {
        final idx = _mensagens.indexWhere((m) => m.id == 'loading');
        if (idx >= 0) {
          _mensagens[idx] = MensagemChat(
            id: '${DateTime.now().millisecondsSinceEpoch}-a',
            tipo: TipoMensagem.assistente,
            conteudo: respostaAcumulada,
            timestamp: DateTime.now(),
            carregando: false,
          );
        }
        _enviando = false;
      });
      _subscription = null;
      _scrollToBottom();
    }

    final chatApiBase =
        await AppParametrosService.instance.getIaChatApiBaseUrl();

    _subscription = _service
        .enviarMensagem(texto, historico, apiBaseUrl: chatApiBase)
        .listen(
          (token) {
            respostaAcumulada += token;
            if (!mounted) return;
            setState(() {
              final idx = _mensagens.indexWhere((m) => m.id == 'loading');
              if (idx >= 0) {
                _mensagens[idx] = _mensagens[idx].copyWith(
                  conteudo: respostaAcumulada,
                  carregando: true,
                );
              }
            });
            _scrollToBottom();
          },
          onDone: finalizarComSucesso,
          onError: (Object e, StackTrace st) {
            finalizarComErro(
              'Erro ao conectar com a IA. Verifique o servidor ($chatApiBase) e a rede.',
            );
          },
          cancelOnError: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: widget.drawer ?? const V2Drawer(),
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: cs.primary),
            const SizedBox(width: 8),
            const Text('FinTrack IA'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpar conversa',
            onPressed: _enviando ? null : _limparConversa,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildListaMensagens()),
          if (_mensagens.isEmpty) _buildSugestoes(),
          ChatInput(
            controller: _controller,
            enviando: _enviando,
            onEnviar: _enviarMensagem,
          ),
        ],
      ),
    );
  }
}
