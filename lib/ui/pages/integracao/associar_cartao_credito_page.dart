import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/integracao_cartoes_api_service.dart';
import 'package:vox_finance/ui/data/models/cartao_api_dto.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/modules/cartoes_credito/cartao_credito_repository.dart';
import 'package:vox_finance/ui/data/modules/integracao/cartao_de_para_repository.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

/// Configuração: associa cartões da API aos cartões cadastrados no app.
class AssociarCartaoCreditoPage extends StatefulWidget {
  const AssociarCartaoCreditoPage({super.key});

  static const routeName = '/integracao/associar-cartao-credito';

  @override
  State<AssociarCartaoCreditoPage> createState() =>
      _AssociarCartaoCreditoPageState();
}

class _AssociarCartaoCreditoPageState extends State<AssociarCartaoCreditoPage> {
  final _apiSvc = IntegracaoCartoesApiService.instance;
  final _cartaoRepo = CartaoCreditoRepository();
  final _deParaRepo = CartaoDeParaRepository();

  bool _loading = true;
  String? _erro;
  List<CartaoApiDto> _api = const [];
  List<CartaoCredito> _locais = const [];
  Map<String, int> _mapa = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final locais = await _cartaoRepo.getCartoesCredito();
      final mapa = await _deParaRepo.obter();
      final api = await _apiSvc.listarCartoes();
      if (!mounted) return;
      setState(() {
        _locais = locais;
        _mapa = mapa;
        _api = api;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
      });
    }
  }

  /// Id do cartão local já vinculado a este [idApi] (mapa legado ou coluna `codigo_cartao_api`).
  int? _localIdParaApi(CartaoApiDto c) {
    final fromMap = _mapa[c.id];
    if (fromMap != null) return fromMap;
    for (final l in _locais) {
      if (l.id != null && l.codigoCartaoApi?.trim() == c.id) {
        return l.id;
      }
    }
    return null;
  }

  Future<void> _salvarCartaoComCodigo(CartaoCredito c, String? codigoApi) async {
    await _cartaoRepo.salvarCartaoCredito(
      CartaoCredito(
        id: c.id,
        descricao: c.descricao,
        bandeira: c.bandeira,
        ultimos4Digitos: c.ultimos4Digitos,
        fotoPath: c.fotoPath,
        diaVencimento: c.diaVencimento,
        diaFechamento: c.diaFechamento,
        tipo: c.tipo,
        controlaFatura: c.controlaFatura,
        limite: c.limite,
        codigoCartaoApi: codigoApi,
      ),
    );
  }

  Future<void> _associar(String idApi, int? idLocal) async {
    try {
      // Remove este código da API de outros cartões locais (evita duplicidade).
      for (final l in _locais) {
        if (l.id == null) continue;
        if (l.codigoCartaoApi?.trim() != idApi) continue;
        if (idLocal != null && l.id == idLocal) continue;
        await _salvarCartaoComCodigo(l, null);
      }

      if (idLocal != null) {
        final loc = await _cartaoRepo.getCartaoCreditoById(idLocal);
        if (loc != null) {
          await _salvarCartaoComCodigo(loc, idApi);
        }
      }

      await _deParaRepo.definir(idApi, idLocal);

      final locais = await _cartaoRepo.getCartoesCredito();
      final m = await _deParaRepo.obter();
      if (!mounted) return;
      setState(() {
        _locais = locais;
        _mapa = m;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Associação salva. Código gravado no cartão cadastrado.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Associar cartão de crédito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar',
            onPressed: _loading ? null : _carregar,
          ),
        ],
      ),
      body:
          _loading
              ? _corpoCarregando(context)
              : _erro != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _carregar,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Associe cada cartão da integração ao cadastro local. '
                      'O código é gravado no cartão do app (usado em Faturas).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_api.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum cartão encontrado na integração.\n'
                            'Confira a URL em Parâmetros e tente novamente.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 0, 16, 24)),
                        itemCount: _api.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = _api[i];
                          final sel = _localIdParaApi(c);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Integração',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  Text(
                                    c.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'Código: ${c.id}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontFamily: 'monospace',
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cartão no aplicativo',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<int?>(
                                    key: ValueKey('${c.id}_$sel'),
                                    initialValue: sel,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    hint: const Text('Não associado'),
                                    items: [
                                      const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('— Não associar —'),
                                      ),
                                      ..._locais
                                          .where((l) => l.id != null)
                                          .map(
                                            (l) => DropdownMenuItem<int?>(
                                              value: l.id,
                                              child: Text(l.label),
                                            ),
                                          ),
                                    ],
                                    onChanged: (v) => _associar(c.id, v),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _corpoCarregando(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        LinearProgressIndicator(
          minHeight: 3,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.primary,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Processando',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Carregando cartões da integração…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
