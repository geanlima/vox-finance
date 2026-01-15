// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../app/di/injector.dart';
import '../../../infrastructure/repositories/notas_rapidas_repository.dart';

enum NotasFiltro { pendentes, todas, concluidas }

class NotasRapidasPage extends StatefulWidget {
  const NotasRapidasPage({super.key});

  @override
  State<NotasRapidasPage> createState() => _NotasRapidasPageState();
}

class _NotasRapidasPageState extends State<NotasRapidasPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  bool _loading = true;
  List<NotaRapidaItem> _itens = const [];
  NotasFiltro _filtro = NotasFiltro.pendentes;

  // Voz
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _vozDisponivel = false;
  bool _ouvindo = false;

  NotasRapidasRepository get _repo => InjectorV2.notasRepo;

  @override
  void initState() {
    super.initState();
    _initVoz();
    _load();
  }

  Future<void> _initVoz() async {
    try {
      final ok = await _stt.initialize();
      if (!mounted) return;
      setState(() => _vozDisponivel = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _vozDisponivel = false);
    }
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);

      final itens = await _repo.listar();

      if (itens.isEmpty) {
        await _repo.adicionar('Revisar gasto mensal', ordem: 1);
        await _repo.adicionar(
          'Verificar no e-mail valor da conta de luz',
          ordem: 2,
        );
        await _repo.adicionar('Revisar metas financeiras', ordem: 3);
        await _repo.adicionar(
          'Atualizar o calendário de vencimentos',
          ordem: 4,
        );
      }

      final atual = await _repo.listar();

      if (!mounted) return;
      setState(() {
        _itens = atual;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar notas: $e')));
    }
  }

  Future<void> _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    _ctrl.clear();
    await _repo.adicionar(text, ordem: _itens.length + 1);
    await _load();
    _focus.requestFocus();
  }

  Future<void> _toggle(NotaRapidaItem item, bool? v) async {
    await _repo.setConcluida(item.id, v == true);
    await _load();
  }

  Future<void> _remove(NotaRapidaItem item) async {
    await _repo.remover(item.id);
    await _load();
  }

  Future<void> _clearDone() async {
    await _repo.limparConcluidas();
    await _load();
  }

  List<NotaRapidaItem> get _itensFiltrados {
    switch (_filtro) {
      case NotasFiltro.pendentes:
        return _itens.where((x) => !x.concluida).toList();
      case NotasFiltro.concluidas:
        return _itens.where((x) => x.concluida).toList();
      case NotasFiltro.todas:
        return _itens;
    }
  }

  int get _pendentes => _itens.where((x) => !x.concluida).length;
  int get _concluidas => _itens.where((x) => x.concluida).length;

  Future<void> _toggleVoz() async {
    if (!_vozDisponivel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voz não disponível neste dispositivo')),
      );
      return;
    }

    if (_ouvindo) {
      await _stt.stop();
      if (!mounted) return;
      setState(() => _ouvindo = false);
      return;
    }

    setState(() => _ouvindo = true);

    await _stt.listen(
      localeId: 'pt_BR',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) {
        // Coloca o texto reconhecido no input
        final txt = result.recognizedWords.trim();
        if (txt.isEmpty) return;

        setState(() => _ctrl.text = txt);

        // Se já é final, para de ouvir e mantém no campo
        if (result.finalResult) {
          _stt.stop();
          setState(() => _ouvindo = false);
          _focus.requestFocus();
        }
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas rápidas'),
        actions: [
          IconButton(
            tooltip: 'Limpar concluídas',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _concluidas > 0 ? _clearDone : null,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    // Card dica
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb_outline, color: cs.primary),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Anote tarefas e lembretes rápidos do dia a dia. Use filtros para ver pendentes ou concluídas.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Chips de filtro
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: Text('Pendentes ($_pendentes)'),
                          selected: _filtro == NotasFiltro.pendentes,
                          onSelected:
                              (_) => setState(
                                () => _filtro = NotasFiltro.pendentes,
                              ),
                        ),
                        ChoiceChip(
                          label: Text('Todas (${_itens.length})'),
                          selected: _filtro == NotasFiltro.todas,
                          onSelected:
                              (_) =>
                                  setState(() => _filtro = NotasFiltro.todas),
                        ),
                        ChoiceChip(
                          label: Text('Concluídas ($_concluidas)'),
                          selected: _filtro == NotasFiltro.concluidas,
                          onSelected:
                              (_) => setState(
                                () => _filtro = NotasFiltro.concluidas,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Campo + voz
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _add(),
                                decoration: const InputDecoration(
                                  hintText: 'Adicionar uma nota…',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),

                            // Microfone
                            IconButton(
                              tooltip:
                                  _ouvindo
                                      ? 'Parar gravação'
                                      : 'Adicionar por voz',
                              onPressed: _toggleVoz,
                              icon: Icon(
                                _ouvindo
                                    ? Icons.stop_circle_outlined
                                    : Icons.mic_none_outlined,
                                color: _ouvindo ? cs.error : null,
                              ),
                            ),

                            FilledButton(
                              onPressed: _add,
                              child: const Text('Adicionar'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_ouvindo) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.hearing, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Ouvindo… fale agora',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Lista
                    if (_itensFiltrados.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.playlist_add,
                              size: 42,
                              color: cs.outline,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _filtro == NotasFiltro.pendentes
                                  ? 'Sem pendências 🎉'
                                  : 'Sem itens aqui.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    else
                      ..._itensFiltrados.map(
                        (item) => _NotaTile(
                          item: item,
                          onToggle: (v) => _toggle(item, v),
                          onDelete: () => _remove(item),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

class _NotaTile extends StatelessWidget {
  final NotaRapidaItem item;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onDelete;

  const _NotaTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('nota_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
        ),
        onDismissed: (_) => onDelete(),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Checkbox(value: item.concluida, onChanged: onToggle),
            title: Text(
              item.texto,
              style: TextStyle(
                decoration: item.concluida ? TextDecoration.lineThrough : null,
                color: item.concluida ? cs.outline : null,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}
