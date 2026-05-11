import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/core/service/api_access_test_service.dart';
import 'package:vox_finance/ui/core/service/app_parametros_service.dart';
import 'package:vox_finance/ui/core/service/backup_auto_cloud_service.dart';
import 'package:vox_finance/ui/core/service/notifications_service.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/fatura_geracao_opcao.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class ParametrosPage extends StatefulWidget {
  const ParametrosPage({super.key});

  static const routeName = '/configuracao-parametros';

  @override
  State<ParametrosPage> createState() => _ParametrosPageState();
}

class _ParametrosPageState extends State<ParametrosPage> {
  final _fmt = DateFormat('dd/MM/yyyy');
  final _cartaoRepo = CartaoCreditoRepository();
  bool _loading = true;
  DateTime? _dataInicio;
  String? _apiBaseUrl;
  final _apiCtrl = TextEditingController();
  final _iaChatCtrl = TextEditingController();
  bool _testandoApi = false;

  bool _backupAutoEnabled = false;
  TimeOfDay _backupAutoTime = const TimeOfDay(hour: 2, minute: 0);
  DateTime? _backupAutoLastRun;
  bool? _backupAutoLastOk;
  String? _backupAutoLastError;

  bool _gerandoFaturas = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppParametrosService.instance.getDataInicioUso();
    final api = await AppParametrosService.instance.getApiBaseUrl();
    final iaChatUrl =
        await AppParametrosService.instance.getIaChatApiBaseUrl() ?? '';
    final enabled = await BackupAutoCloudService.instance.isEnabled();
    final mins = await BackupAutoCloudService.instance.timeMinutes();
    final (lastRun, lastOk, lastErr) =
        await BackupAutoCloudService.instance.lastRun();
    if (!mounted) return;
    setState(() {
      _dataInicio = d;
      _apiBaseUrl = api;
      _apiCtrl.text = api ?? '';
      _iaChatCtrl.text = iaChatUrl;
      _backupAutoEnabled = enabled;
      if (mins != null) {
        _backupAutoTime = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
      }
      _backupAutoLastRun = lastRun;
      _backupAutoLastOk = lastOk;
      _backupAutoLastError = lastErr;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _apiCtrl.dispose();
    _iaChatCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarIaChatUrl() async {
    final raw = _iaChatCtrl.text;
    if (!_apiUrlValida(raw) || raw.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma URL válida (http/https).'),
        ),
      );
      return;
    }
    final v = raw.trim().replaceAll(RegExp(r'/+$'), '');
    await AppParametrosService.instance.setIaChatApiBaseUrl(v);
    if (!mounted) return;
    final resolved =
        await AppParametrosService.instance.getIaChatApiBaseUrl() ?? '';
    if (!mounted) return;
    setState(() => _iaChatCtrl.text = resolved);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL do FinTrack IA salva.')),
    );
  }

  Future<void> _limparUrlIaChat() async {
    await AppParametrosService.instance.limparIaChatApiBaseUrl();
    if (!mounted) return;
    setState(() => _iaChatCtrl.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL do FinTrack IA removida.'),
      ),
    );
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
        const SnackBar(content: Text('URL de integração removida.')),
      );
      return;
    }

    await AppParametrosService.instance.setApiBaseUrl(v);
    if (!mounted) return;
    setState(() => _apiBaseUrl = v);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL de integração salva.')),
    );
  }

  Future<void> _testarApi() async {
    final raw = _apiCtrl.text;
    if (!_apiUrlValida(raw) || raw.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma URL válida (http/https) antes de testar.'),
        ),
      );
      return;
    }

    setState(() => _testandoApi = true);
    final res = await ApiAccessTestService.instance.testarUrlBase(raw);
    if (!mounted) return;
    setState(() => _testandoApi = false);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            res.sucesso
                ? 'Conexão estabelecida com sucesso'
                : 'Não foi possível conectar',
          ),
          content: SingleChildScrollView(
            child: Text(res.mensagem),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _gerarFaturasExistentes() async {
    try {
      final selecionadas = await showDialog<List<FaturaGeracaoOpcao>>(
        context: context,
        builder: (ctx) => _GerarFaturasExistentesDialog(repo: _cartaoRepo),
      );
      if (selecionadas == null || selecionadas.isEmpty) return;

      setState(() => _gerandoFaturas = true);
      final qtd = await _cartaoRepo.gerarFaturasSelecionadas(
        selecionadas: selecionadas,
        overwrite: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Faturas geradas/atualizadas: $qtd')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar faturas: $e')),
      );
    } finally {
      if (mounted) setState(() => _gerandoFaturas = false);
    }
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
                padding: listViewPaddingWithBottomInset(context, const EdgeInsets.all(16)),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faturas de cartão',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cria/atualiza automaticamente o lançamento de fatura no vencimento '
                            'conforme você lança compras no crédito. Se você já tem lançamentos antigos, '
                            'use o botão abaixo para gerar as faturas retroativamente.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _gerandoFaturas ? null : _gerarFaturasExistentes,
                              icon: _gerandoFaturas
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.receipt_long_outlined, size: 20),
                              label: Text(
                                _gerandoFaturas
                                    ? 'Gerando...'
                                    : 'Gerar faturas dos lançamentos existentes',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup automático na nuvem',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Quando ativado, o app agenda um backup diário na nuvem no horário definido '
                            '(o mesmo backup da tela “Backup na nuvem”).',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Ativar backup automático'),
                            value: _backupAutoEnabled,
                            onChanged: (v) async {
                              if (v) {
                                await NotificationService
                                    .requestAndroidPostNotificationsPermission();
                              }
                              setState(() => _backupAutoEnabled = v);
                              await BackupAutoCloudService.instance.setEnabled(v);
                              final (lastRun, lastOk, lastErr) =
                                  await BackupAutoCloudService.instance.lastRun();
                              if (!mounted) return;
                              setState(() {
                                _backupAutoLastRun = lastRun;
                                _backupAutoLastOk = lastOk;
                                _backupAutoLastError = lastErr;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    v
                                        ? 'Backup automático ativado.'
                                        : 'Backup automático desativado.',
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: !_backupAutoEnabled
                                      ? null
                                      : () async {
                                          final picked = await showTimePicker(
                                            context: context,
                                            initialTime: _backupAutoTime,
                                          );
                                          if (picked == null || !mounted) return;
                                          setState(() => _backupAutoTime = picked);
                                          await BackupAutoCloudService.instance.setDailyTime(
                                            hour: picked.hour,
                                            minute: picked.minute,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Horário salvo: ${picked.format(context)}',
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.schedule, size: 20),
                                  label: Text(
                                    'Horário: ${_backupAutoTime.format(context)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_backupAutoLastRun != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Última execução: '
                              '${DateFormat("dd/MM/yyyy 'às' HH:mm").format(_backupAutoLastRun!)}'
                              '${_backupAutoLastOk == null ? '' : (_backupAutoLastOk! ? ' · OK' : ' · Falha')}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_backupAutoLastOk == false &&
                                _backupAutoLastError != null &&
                                _backupAutoLastError!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _backupAutoLastError!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
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
                            'FinTrack IA — chat',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'URL base da API usada pelo chat (rota POST /api/Chat). '
                            'Obrigatório para usar o FinTrack IA.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _iaChatCtrl,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'URL base do FinTrack IA',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _limparUrlIaChat,
                                  child: const Text('Limpar URL'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _salvarIaChatUrl,
                                  icon: const Icon(Icons.save_outlined, size: 20),
                                  label: const Text('Salvar'),
                                ),
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
                            'Acesso à integração',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Informe a URL base do servidor (ex.: https://servidor.seudominio.com). '
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
                              labelText: 'URL de integração',
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
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _testandoApi ? null : _testarApi,
                                  icon: _testandoApi
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.wifi_tethering, size: 20),
                                  label: Text(
                                    _testandoApi ? 'Testando...' : 'Testar conexão',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _salvarApiUrl,
                              icon: const Icon(Icons.save, size: 20),
                              label: const Text('Salvar URL'),
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

class _GerarFaturasExistentesDialog extends StatefulWidget {
  const _GerarFaturasExistentesDialog({required this.repo});

  final CartaoCreditoRepository repo;

  @override
  State<_GerarFaturasExistentesDialog> createState() =>
      _GerarFaturasExistentesDialogState();
}

class _GerarFaturasExistentesDialogState
    extends State<_GerarFaturasExistentesDialog> {
  List<FaturaGeracaoOpcao> _opcoes = [];
  final Set<String> _selecionadas = {};
  bool _carregando = true;
  bool _incluirPagas = false;
  int? _filtroCartaoId;
  int? _filtroMes;
  int? _filtroAno;
  List<CartaoCredito> _cartoesFiltro = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final todos = await widget.repo.getCartoesCredito();
    if (!mounted) return;
    setState(() {
      _cartoesFiltro =
          todos.where((c) {
            if (c.id == null) return false;
            if (!(c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos)) {
              return false;
            }
            if (!c.controlaFatura) return false;
            if (c.diaFechamento == null || c.diaVencimento == null) {
              return false;
            }
            return true;
          }).toList();
    });
    await _recarregarOpcoes();
  }

  Future<void> _recarregarOpcoes() async {
    setState(() => _carregando = true);
    final op = await widget.repo.listarOpcoesGeracaoFaturas(
      somenteEmAberto: !_incluirPagas,
      filtroIdCartao: _filtroCartaoId,
      anoReferencia: _filtroAno,
      mesReferencia: _filtroMes,
    );
    if (!mounted) return;
    setState(() {
      _opcoes = op;
      _carregando = false;
      _selecionadas
        ..clear()
        ..addAll(
          op.where((e) => !e.faturaConstaComoPaga).map((e) => e.key),
        );
    });
  }

  Widget _filtroCartaoDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Cartão',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _filtroCartaoId,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos'),
            ),
            ..._cartoesFiltro.map(
              (c) => DropdownMenuItem<int?>(
                value: c.id,
                child: Text(c.label),
              ),
            ),
          ],
          onChanged: _carregando
              ? null
              : (v) async {
                  setState(() => _filtroCartaoId = v);
                  await _recarregarOpcoes();
                },
        ),
      ),
    );
  }

  Widget _filtroMesDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Mês ref.',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _filtroMes,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos'),
            ),
            ...List.generate(
              12,
              (i) => DropdownMenuItem<int?>(
                value: i + 1,
                child: Text((i + 1).toString().padLeft(2, '0')),
              ),
            ),
          ],
          onChanged: _carregando
              ? null
              : (v) async {
                  setState(() => _filtroMes = v);
                  await _recarregarOpcoes();
                },
        ),
      ),
    );
  }

  Widget _filtroAnoDropdown(List<int> anos) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Ano ref.',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _filtroAno,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Todos'),
            ),
            ...anos.map(
              (y) => DropdownMenuItem<int?>(
                value: y,
                child: Text(y.toString()),
              ),
            ),
          ],
          onChanged: _carregando
              ? null
              : (v) async {
                  setState(() => _filtroAno = v);
                  await _recarregarOpcoes();
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final anos = [for (var y = agora.year - 6; y <= agora.year + 2; y++) y];
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    return AlertDialog(
      title: const Text('Gerar faturas por período'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir faturas pagas na lista'),
                  subtitle: const Text(
                    'Só para consulta: períodos pagos não podem ser regerados.',
                  ),
                  value: _incluirPagas,
                  onChanged: _carregando
                      ? null
                      : (v) async {
                          setState(() => _incluirPagas = v);
                          await _recarregarOpcoes();
                        },
                ),
                const SizedBox(height: 8),
                if (narrow) ...[
                  _filtroCartaoDropdown(),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _filtroMesDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _filtroAnoDropdown(anos)),
                    ],
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _filtroCartaoDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _filtroMesDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _filtroAnoDropdown(anos)),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _carregando || _opcoes.isEmpty
                            ? null
                            : () => setState(() {
                                  _selecionadas
                                    ..clear()
                                    ..addAll(
                                      _opcoes
                                          .where((e) => !e.faturaConstaComoPaga)
                                          .map((e) => e.key),
                                    );
                                }),
                        child: const Text('Marcar tudo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _carregando
                            ? null
                            : () => setState(() => _selecionadas.clear()),
                        child: const Text('Limpar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_opcoes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhum período encontrado com os filtros. Faturas já pagas '
                      'ficam ocultas até você ligar “Incluir faturas pagas”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: listScrollBottomInset(context),
                    ),
                    itemCount: _opcoes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final o = _opcoes[i];
                      final checked = _selecionadas.contains(o.key);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: o.faturaConstaComoPaga
                            ? null
                            : (v) {
                                setState(() {
                                  if (v == true) {
                                    _selecionadas.add(o.key);
                                  } else {
                                    _selecionadas.remove(o.key);
                                  }
                                });
                              },
                        title: Text('${o.referenciaLabel} · ${o.cartaoLabel}'),
                        subtitle: Text(
                          'Venc. ${o.vencimentoLabel}'
                          '${o.faturaConstaComoPaga ? ' • Fatura paga' : ''}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                const SizedBox(height: 8),
                Text(
                  'Por padrão só faturas em aberto. Períodos já pagos não são regerados.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selecionadas.isEmpty
              ? null
              : () {
                  final out = <FaturaGeracaoOpcao>[
                    for (final o in _opcoes)
                      if (_selecionadas.contains(o.key)) o,
                  ];
                  Navigator.pop(context, out);
                },
          child: Text('Gerar (${_selecionadas.length})'),
        ),
      ],
    );
  }
}
