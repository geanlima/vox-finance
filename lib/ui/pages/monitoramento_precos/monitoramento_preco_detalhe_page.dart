import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco.dart';
import 'package:vox_finance/ui/data/models/monitoramento_preco_oferta.dart';
import 'package:vox_finance/ui/data/modules/monitoramento_precos/monitoramento_preco_repository.dart';
import 'package:vox_finance/ui/pages/monitoramento_precos/monitoramento_preco_loja_detalhe_page.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class MonitoramentoPrecoDetalhePage extends StatefulWidget {
  const MonitoramentoPrecoDetalhePage({super.key, required this.produto});

  static const routeName = '/monitoramento-precos/detalhe';

  final MonitoramentoPreco produto;

  @override
  State<MonitoramentoPrecoDetalhePage> createState() =>
      _MonitoramentoPrecoDetalhePageState();
}

class _MonitoramentoPrecoDetalhePageState
    extends State<MonitoramentoPrecoDetalhePage> {
  final _repo = MonitoramentoPrecoRepository();
  final _money = NumberFormat.simpleCurrency(locale: 'pt_BR');
  final _date = DateFormat('dd/MM/yyyy HH:mm');

  /// Força exibição no horário de Brasília (BRT, UTC-3).
  /// Usamos a conversão a partir do instante UTC para ficar independente do fuso do aparelho.
  DateTime _toBrasilia(DateTime dt) => dt.toUtc().subtract(const Duration(hours: 3));

  bool _loading = true;
  List<MonitoramentoPrecoOferta> _ofertas = const [];
  late MonitoramentoPreco _produto;

  @override
  void initState() {
    super.initState();
    _produto = widget.produto;
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _ehUrlImagem(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp');
  }

  String? _extrairImagemDoHtml(String html) {
    final patterns = <RegExp>[
      RegExp(
        "property=['\\\"]og:image['\\\"][^>]*content=['\\\"]([^'\\\"]+)['\\\"]",
        caseSensitive: false,
      ),
      RegExp(
        "name=['\\\"]twitter:image['\\\"][^>]*content=['\\\"]([^'\\\"]+)['\\\"]",
        caseSensitive: false,
      ),
      RegExp(
        "itemprop=['\\\"]image['\\\"][^>]*content=['\\\"]([^'\\\"]+)['\\\"]",
        caseSensitive: false,
      ),
    ];
    for (final r in patterns) {
      final m = r.firstMatch(html);
      final v = m?.group(1)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Future<Uri?> _resolverImagemPorLink(String pageUrl) async {
    final raw = pageUrl.trim();
    if (raw.isEmpty) return null;
    Uri page;
    try {
      page = Uri.parse(raw);
    } catch (_) {
      return null;
    }
    if (!(page.isScheme('http') || page.isScheme('https'))) return null;

    if (_ehUrlImagem(raw)) return page;

    final resp = await http.get(page);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final html = resp.body;
    final img = _extrairImagemDoHtml(html);
    if (img == null) return null;

    try {
      final imgUri = Uri.parse(img);
      return imgUri.hasScheme ? imgUri : page.resolveUri(imgUri);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _baixarImagemParaArquivo(Uri imgUrl, int idMonitoramento) async {
    final resp = await http.get(imgUrl);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) return null;

    final contentType = resp.headers['content-type']?.toLowerCase() ?? '';
    String ext = '.jpg';
    if (contentType.contains('png')) ext = '.png';
    if (contentType.contains('webp')) ext = '.webp';
    if (_ehUrlImagem(imgUrl.toString())) {
      final pathExt = p.extension(imgUrl.path);
      if (pathExt.isNotEmpty) ext = pathExt;
    }

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'monitoramento_precos'));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final filename =
        'produto_${idMonitoramento}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final filePath = p.join(folder.path, filename);
    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<void> _buscarFotoPeloLinkEAplicar(String link) async {
    final id = _produto.id;
    if (id == null) return;

    try {
      final img = await _resolverImagemPorLink(link);
      if (img == null) {
        _snack('Não consegui encontrar imagem no link.');
        return;
      }
      final savedPath = await _baixarImagemParaArquivo(img, id);
      if (savedPath == null) {
        _snack('Não consegui baixar a imagem.');
        return;
      }

      final now = DateTime.now();
      final novo = _produto.copyWith(fotoPath: savedPath, atualizadoEm: now);
      await _repo.salvar(novo);
      if (!mounted) return;
      setState(() => _produto = novo);
      _snack('Foto atualizada pelo link.');
    } catch (_) {
      _snack('Não consegui baixar a imagem pelo link.');
    }
  }

  Future<bool> _tentarBuscarFotoPeloLinkSemAlterarSeFalhar(String link) async {
    final id = _produto.id;
    if (id == null) return false;
    final trimmed = link.trim();
    if (trimmed.isEmpty) return false;

    try {
      final img = await _resolverImagemPorLink(trimmed);
      if (img == null) return false;
      final savedPath = await _baixarImagemParaArquivo(img, id);
      if (savedPath == null) return false;

      final now = DateTime.now();
      final novo = _produto.copyWith(fotoPath: savedPath, atualizadoEm: now);
      await _repo.salvar(novo);
      if (!mounted) return true;
      setState(() => _produto = novo);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    final id = _produto.id;
    if (id == null) return;
    setState(() => _loading = true);
    final rows = await _repo.listarOfertas(id);
    if (!mounted) return;
    setState(() {
      _ofertas = rows;
      _loading = false;
    });
  }

  Future<void> _editarProduto() async {
    final item = _produto;
    if (item.id == null) return;

    final produtoCtrl = TextEditingController(text: item.produto);
    String? fotoPath = item.fotoPath;
    bool autoFetchDisparado = false;

    final salvo = await showModalBottomSheet<MonitoramentoPreco?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final bottomPad = 28 + mq.viewInsets.bottom + mq.viewPadding.bottom;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> pickImage() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );
              final path = result?.files.single.path;
              if (path == null || path.trim().isEmpty) return;
              setModal(() => fotoPath = path);
            }

            Future<void> buscarFotoAutomaticamenteSePreciso() async {
              if (autoFetchDisparado) return;
              final semFoto = fotoPath == null || fotoPath!.trim().isEmpty;
              if (!semFoto) return;
              // pega o primeiro link disponível nas ofertas
              final link =
                  _ofertas
                      .map((o) => (o.url ?? '').trim())
                      .firstWhere((u) => u.isNotEmpty, orElse: () => '');
              if (link.isEmpty) return;

              autoFetchDisparado = true;
              final ok = await _tentarBuscarFotoPeloLinkSemAlterarSeFalhar(link);
              if (!ctx.mounted) return;
              if (ok) {
                setModal(() => fotoPath = _produto.fotoPath);
              }
            }

            // Ao abrir o editar, se não tiver imagem tenta buscar pelo link.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!ctx.mounted) return;
              buscarFotoAutomaticamenteSePreciso();
            });

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Editar produto',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: pickImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                              border: Border.all(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: (fotoPath != null &&
                                      fotoPath!.trim().isNotEmpty &&
                                      File(fotoPath!).existsSync())
                                  ? Image.file(
                                      File(fotoPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.photo_camera_outlined,
                                      color: Theme.of(ctx).colorScheme.outline,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: produtoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Produto',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (fotoPath != null && fotoPath!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setModal(() => fotoPath = null),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remover foto'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        final nome = produtoCtrl.text.trim();
                        if (nome.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Informe o produto.')),
                          );
                          return;
                        }
                        final now = DateTime.now();
                        final novo = item.copyWith(
                          produto: nome,
                          fotoPath:
                              (fotoPath == null || fotoPath!.trim().isEmpty)
                                  ? null
                                  : fotoPath,
                          atualizadoEm: now,
                        );
                        await _repo.salvar(novo);

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, _produto);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (salvo != null && mounted) {
      setState(() => _produto = salvo);
      Navigator.pop(context, true); // força recarregar lista principal
    }
  }

  Future<void> _openLojaForm({MonitoramentoPrecoOferta? loja}) async {
    final idMon = _produto.id;
    if (idMon == null) return;

    final lojaCtrl = TextEditingController(text: loja?.loja ?? '');
    final urlCtrl = TextEditingController(text: loja?.url ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModal) {
            bool baixandoFoto = false;
            final bottomPad =
                28 + mq.viewInsets.bottom + mq.viewPadding.bottom;
            final linkAtual = urlCtrl.text.trim();

            Future<void> usarFotoPeloLink() async {
              final link = urlCtrl.text.trim();
              if (link.isEmpty) return;
              setModal(() => baixandoFoto = true);
              await _buscarFotoPeloLinkEAplicar(link);
              if (ctx.mounted) setModal(() => baixandoFoto = false);
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loja == null ? 'Adicionar loja' : 'Editar loja',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lojaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Loja / site',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setModal(() {}),
                    ),
                    if (linkAtual.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: baixandoFoto ? null : usarFotoPeloLink,
                          icon: baixandoFoto
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.image_search_outlined),
                          label: const Text(
                            'Buscar foto pelo link e usar no produto',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                    final nomeLoja = lojaCtrl.text.trim();
                    final url = urlCtrl.text.trim();
                    final now = DateTime.now();
                    final obj = (loja == null)
                        ? MonitoramentoPrecoOferta(
                            idMonitoramento: idMon,
                            loja: nomeLoja.isEmpty ? null : nomeLoja,
                            url: url.isEmpty ? null : url,
                            preco: 0,
                            criadoEm: now,
                            atualizadoEm: now,
                          )
                        : loja.copyWith(
                            loja: nomeLoja.isEmpty ? null : nomeLoja,
                            url: url.isEmpty ? null : url,
                            atualizadoEm: now,
                          );

                    await _repo.salvarLoja(obj);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                      },
                      child: const Text('Salvar'),
                    ),
                    if (loja?.id != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(ctx)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Remover loja'),
                              content: const Text('Deseja remover esta loja?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dctx, true),
                                  child: const Text('Remover'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await _repo.deletarOferta(loja!.id!);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx, true);
                        },
                        label: const Text('Remover'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (ok == true) {
      await _load();
      _snack('Loja salva.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final produto = _produto;
    final foto = (produto.fotoPath ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(produto.produto),
        actions: [
          IconButton(
            tooltip: 'Editar produto',
            onPressed: _editarProduto,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openLojaForm(),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar loja'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: listViewPaddingWithBottomInset(context, const EdgeInsets.fromLTRB(16, 12, 16, 24)),
              children: [
                Card(
                  child: ListTile(
                    leading: foto.isEmpty
                        ? const CircleAvatar(
                            child: Icon(Icons.local_offer_outlined),
                          )
                        : CircleAvatar(backgroundImage: FileImage(File(foto))),
                    title: const Text('Produto'),
                    subtitle: Text(produto.produto),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Lojas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                if (_ofertas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Nenhuma loja adicionada ainda.\n\nToque em “Adicionar loja”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                else
                  ..._ofertas.map((o) {
                    final loja = (o.loja ?? '').trim();
                    final url = (o.url ?? '').trim();
                    final sub = <String>[
                      if (loja.isNotEmpty) loja,
                      if (url.isNotEmpty) url,
                    ].join(' • ');
                    return Slidable(
                      key: ValueKey('loja_${o.id ?? loja}'),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.34,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _openLojaForm(loja: o),
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) async {
                              final id = o.id;
                              if (id == null) return;
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remover loja'),
                                  content: const Text(
                                    'Deseja remover esta loja e todo o histórico de preços?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remover'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              await _repo.deletarOferta(id);
                              await _load();
                              _snack('Loja removida.');
                            },
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(
                            loja.isEmpty ? 'Loja não informada' : loja,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: sub.isEmpty ? null : Text(sub, maxLines: 2),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                o.preco <= 0 ? '—' : _money.format(o.preco),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _date.format(_toBrasilia(o.atualizadoEm)),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MonitoramentoPrecoLojaDetalhePage(
                                  loja: o,
                                  onTrySetProductImageFromUrl: (url) async {
                                    final semFoto = _produto.fotoPath == null ||
                                        _produto.fotoPath!.trim().isEmpty;
                                    if (!semFoto) return;
                                    await _buscarFotoPeloLinkEAplicar(url);
                                  },
                                ),
                              ),
                            );
                            if (changed == true) await _load();
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

