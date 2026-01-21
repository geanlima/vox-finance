// ignore_for_file: deprecated_member_use, unreachable_switch_default

import 'package:flutter/material.dart';
import 'package:vox_finance/v2/widgets/v2_drawer.dart';

class HomePageV2 extends StatefulWidget {
  const HomePageV2({super.key});

  static const String routeName = '/v2/home';

  @override
  State<HomePageV2> createState() => _HomePageV2State();
}

class _HomePageV2State extends State<HomePageV2> {
  // ✅ começa vazio
  final List<_NotificacaoItem> _items = [];

  bool _somenteNaoLidas = false;

  List<_NotificacaoItem> get _view =>
      _somenteNaoLidas ? _items.where((e) => !e.lida).toList() : _items;

  int get _naoLidas => _items.where((e) => !e.lida).length;

  void _toggleFiltro(bool v) => setState(() => _somenteNaoLidas = v);

  void _marcarLida(_NotificacaoItem n, bool lida) {
    setState(() {
      final idx = _items.indexWhere((e) => e.id == n.id);
      if (idx >= 0) _items[idx] = _items[idx].copyWith(lida: lida);
    });
  }

  void _remover(_NotificacaoItem n) {
    setState(() => _items.removeWhere((e) => e.id == n.id));
  }

  void _limparLidas() {
    setState(() => _items.removeWhere((e) => e.lida));
  }

  Future<void> _criarNotificacao() async {
    final created = await Navigator.push<_NotificacaoItem>(
      context,
      MaterialPageRoute(builder: (_) => const _CriarNotificacaoPage()),
    );

    if (created == null) return;

    setState(() {
      _items.insert(0, created);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const V2Drawer(),
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_items.any((e) => e.lida))
            IconButton(
              tooltip: 'Limpar lidas',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: _limparLidas,
            ),
          IconButton(
            tooltip: 'Marcar todas como lidas',
            icon: const Icon(Icons.done_all),
            onPressed:
                _naoLidas == 0
                    ? null
                    : () {
                      setState(() {
                        for (var i = 0; i < _items.length; i++) {
                          _items[i] = _items[i].copyWith(lida: true);
                        }
                      });
                    },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _naoLidas == 0 ? 'Tudo em dia ✅' : '$_naoLidas não lida(s)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Somente não lidas'),
                  selected: _somenteNaoLidas,
                  onSelected: _toggleFiltro,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child:
                _view.isEmpty
                    ? _EmptyState(
                      somenteNaoLidas: _somenteNaoLidas,
                      onVerTodas: () => _toggleFiltro(false),
                      onCriar: _criarNotificacao,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _view.length,
                      itemBuilder: (_, i) {
                        final n = _view[i];
                        final tipoColor = _tipoColor(cs, n.tipo);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey('notif_${n.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: cs.onErrorContainer,
                              ),
                            ),
                            onDismissed: (_) => _remover(n),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: cs.outlineVariant),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: tipoColor.withOpacity(.15),
                                  child: Icon(
                                    _tipoIcon(n.tipo),
                                    color: tipoColor,
                                  ),
                                ),
                                title: Text(
                                  n.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: n.lida ? cs.outline : null,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (n.mensagem.isNotEmpty)
                                        Text(
                                          n.mensagem,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: n.lida ? cs.outline : null,
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _fmtQuando(n.data),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(color: cs.outline),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip:
                                      n.lida
                                          ? 'Marcar como não lida'
                                          : 'Marcar como lida',
                                  icon: Icon(
                                    n.lida
                                        ? Icons.mark_email_unread_outlined
                                        : Icons.mark_email_read_outlined,
                                  ),
                                  onPressed: () => _marcarLida(n, !n.lida),
                                ),
                                onTap: () {
                                  if (!n.lida) _marcarLida(n, true);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Criar notificação',
        onPressed: _criarNotificacao,
        child: const Icon(Icons.add),
      ),
    );
  }

  static IconData _tipoIcon(_NotificacaoTipo t) {
    switch (t) {
      case _NotificacaoTipo.alerta:
        return Icons.warning_amber_rounded;
      case _NotificacaoTipo.dica:
        return Icons.lightbulb_outline;
      case _NotificacaoTipo.sucesso:
        return Icons.check_circle_outline;
      case _NotificacaoTipo.info:
      default:
        return Icons.notifications_none;
    }
  }

  static Color _tipoColor(ColorScheme cs, _NotificacaoTipo t) {
    switch (t) {
      case _NotificacaoTipo.alerta:
        return cs.error;
      case _NotificacaoTipo.dica:
        return cs.tertiary;
      case _NotificacaoTipo.sucesso:
        return Colors.green;
      case _NotificacaoTipo.info:
      default:
        return cs.primary;
    }
  }

  static String _fmtQuando(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);

    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
    if (diff.inHours < 24) return '${diff.inHours} h atrás';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return '${diff.inDays} dias atrás';

    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final bool somenteNaoLidas;
  final VoidCallback onVerTodas;
  final VoidCallback onCriar;

  const _EmptyState({
    required this.somenteNaoLidas,
    required this.onVerTodas,
    required this.onCriar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 52, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              somenteNaoLidas
                  ? 'Nenhuma notificação não lida.'
                  : 'Nenhuma notificação por aqui.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              somenteNaoLidas
                  ? 'Troque o filtro para ver todas.'
                  : 'Crie sua primeira notificação para começar.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onCriar,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar notificação'),
                ),
                if (somenteNaoLidas)
                  OutlinedButton(
                    onPressed: onVerTodas,
                    child: const Text('Ver todas'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================
// Tela de criar notificação
// ==========================
class _CriarNotificacaoPage extends StatefulWidget {
  const _CriarNotificacaoPage();

  @override
  State<_CriarNotificacaoPage> createState() => _CriarNotificacaoPageState();
}

class _CriarNotificacaoPageState extends State<_CriarNotificacaoPage> {
  final _formKey = GlobalKey<FormState>();

  final _tituloCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  _NotificacaoTipo _tipo = _NotificacaoTipo.info;
  bool _lida = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final item = _NotificacaoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      titulo: _tituloCtrl.text.trim(),
      mensagem: _msgCtrl.text.trim(),
      tipo: _tipo,
      data: DateTime.now(),
      lida: _lida,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar notificação'),
        actions: [
          IconButton(
            tooltip: 'Salvar',
            icon: const Icon(Icons.save),
            onPressed: _salvar,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<_NotificacaoTipo>(
                  value: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _NotificacaoTipo.info,
                      child: Text('Info'),
                    ),
                    DropdownMenuItem(
                      value: _NotificacaoTipo.dica,
                      child: Text('Dica'),
                    ),
                    DropdownMenuItem(
                      value: _NotificacaoTipo.alerta,
                      child: Text('Alerta'),
                    ),
                    DropdownMenuItem(
                      value: _NotificacaoTipo.sucesso,
                      child: Text('Sucesso'),
                    ),
                  ],
                  onChanged:
                      (v) => setState(() => _tipo = v ?? _NotificacaoTipo.info),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Informe um título';
                    if (t.length < 3) return 'Título muito curto';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _msgCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _lida,
                  onChanged: (v) => setState(() => _lida = v),
                  title: const Text('Marcar como lida'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.check),
                    label: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _NotificacaoTipo { info, dica, alerta, sucesso }

class _NotificacaoItem {
  final int id;
  final String titulo;
  final String mensagem;
  final _NotificacaoTipo tipo;
  final DateTime data;
  final bool lida;

  const _NotificacaoItem({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.data,
    required this.lida,
  });

  _NotificacaoItem copyWith({
    String? titulo,
    String? mensagem,
    _NotificacaoTipo? tipo,
    DateTime? data,
    bool? lida,
  }) {
    return _NotificacaoItem(
      id: id,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo ?? this.tipo,
      data: data ?? this.data,
      lida: lida ?? this.lida,
    );
  }
}


