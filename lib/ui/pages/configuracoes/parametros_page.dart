import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class ParametrosPage extends StatefulWidget {
  const ParametrosPage({super.key});

  static const routeName = '/configuracao-parametros';

  @override
  State<ParametrosPage> createState() => _ParametrosPageState();
}

class _ParametrosPageState extends State<ParametrosPage> {
  final _fmt = DateFormat('dd/MM/yyyy');
  bool _loading = true;
  DateTime? _dataInicio;
  String? _apiBaseUrl;
  final _apiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppParametrosService.instance.getDataInicioUso();
    final api = await AppParametrosService.instance.getApiBaseUrl();
    if (!mounted) return;
    setState(() {
      _dataInicio = d;
      _apiBaseUrl = api;
      _apiCtrl.text = api ?? '';
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final now = DateTime.now();
    final initial = _dataInicio ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    await AppParametrosService.instance.setDataInicioUso(picked);
    if (!mounted) return;
    setState(() => _dataInicio = DateTime(picked.year, picked.month, picked.day));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data de início salva. O app desconsidera movimentos anteriores a essa data onde aplicável.',
        ),
      ),
    );
  }

  Future<void> _limpar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover data de início?'),
        content: const Text(
          'O app voltará a considerar todo o histórico (ex.: despesas fixas).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppParametrosService.instance.limparDataInicioUso();
    if (!mounted) return;
    setState(() => _dataInicio = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data de início removida.')),
    );
  }

  bool _apiUrlValida(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return true;
    final uri = Uri.tryParse(v);
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _salvarApiUrl() async {
    final raw = _apiCtrl.text;
    if (!_apiUrlValida(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma URL válida (http/https).'),
        ),
      );
      return;
    }

    final v = raw.trim();
    if (v.isEmpty) {
      await AppParametrosService.instance.limparApiBaseUrl();
      if (!mounted) return;
      setState(() => _apiBaseUrl = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL da API removida.')),
      );
      return;
    }

    await AppParametrosService.instance.setApiBaseUrl(v);
    if (!mounted) return;
    setState(() => _apiBaseUrl = v);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL da API salva.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parâmetros'),
      ),
      drawer: const AppDrawer(currentRoute: ParametrosPage.routeName),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data de início de uso',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Informe o dia em que você passou a usar o app com este banco de dados. '
                            'Movimentos anteriores a essa data serão desconsiderados em telas como '
                            'despesas fixas (fechamento do mês, avisos e geração automática).',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _dataInicio == null
                                      ? 'Não definida (todo o histórico é considerado)'
                                      : 'Definida: ${_fmt.format(_dataInicio!)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _escolherData,
                                icon: const Icon(Icons.calendar_today, size: 20),
                                label: Text(
                                  _dataInicio == null
                                      ? 'Definir data'
                                      : 'Alterar data',
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_dataInicio != null)
                                OutlinedButton(
                                  onPressed: _limpar,
                                  child: const Text('Remover'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acesso à API',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Informe a URL base da API (ex.: https://api.seudominio.com). '
                            'Se ficar em branco, o app não usa integração.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apiCtrl,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'URL da API',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _apiBaseUrl == null
                                      ? 'Não configurada'
                                      : 'Atual: $_apiBaseUrl',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _salvarApiUrl,
                              icon: const Icon(Icons.save, size: 20),
                              label: const Text('Salvar URL da API'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
