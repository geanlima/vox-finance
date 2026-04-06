import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/models/investimento_carteira.dart';
import 'package:vox_finance/ui/data/models/investimento_layout_catalog.dart';
import 'package:vox_finance/ui/data/modules/investimentos/carteira_investimento_repository.dart';
import 'package:vox_finance/ui/pages/investimentos/bluminers/bluminers_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

/// Lista de carteiras; cada uma usa um layout (ex.: Bluminers).
class CarteirasInvestimentoPage extends StatefulWidget {
  const CarteirasInvestimentoPage({super.key});

  @override
  State<CarteirasInvestimentoPage> createState() =>
      _CarteirasInvestimentoPageState();
}

class _CarteirasInvestimentoPageState extends State<CarteirasInvestimentoPage> {
  final _repo = CarteiraInvestimentoRepository();
  final _fmt = DateFormat('dd/MM/yyyy', 'pt_BR');

  bool _loading = true;
  List<InvestimentoCarteira> _itens = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _repo.listar();
    if (!mounted) return;
    setState(() {
      _itens = rows;
      _loading = false;
    });
  }

  Future<void> _abrirCarteira(InvestimentoCarteira c) async {
    if (c.id == null) return;

    switch (c.layout) {
      case 'bluminers':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder:
                (_) => BluminersPage(
                  idCarteira: c.id!,
                  nomeCarteira: c.nome,
                ),
          ),
        );
        await _load();
        return;
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Layout "${InvestimentoLayoutCatalog.tituloOuId(c.layout)}" ainda não está disponível no app.',
            ),
          ),
        );
    }
  }

  Future<void> _openForm({InvestimentoCarteira? item}) async {
    final nomeCtrl = TextEditingController(text: item?.nome ?? '');
    var layoutId = item?.layout ?? InvestimentoLayoutCatalog.padraoId;
    if (!InvestimentoLayoutCatalog.existe(layoutId)) {
      layoutId = InvestimentoLayoutCatalog.padraoId;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final mq = MediaQuery.of(ctx);
            final def = InvestimentoLayoutCatalog.porId(layoutId);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16 + mq.viewInsets.bottom + mq.viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item == null ? 'Nova carteira' : 'Editar carteira',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  DropdownMenu<String>(
                    width: MediaQuery.sizeOf(ctx).width - 32,
                    initialSelection: layoutId,
                    label: const Text('Layout'),
                    dropdownMenuEntries:
                        InvestimentoLayoutCatalog.todos
                            .map(
                              (e) => DropdownMenuEntry<String>(
                                value: e.id,
                                label: e.titulo,
                              ),
                            )
                            .toList(),
                    onSelected: (v) {
                      if (v == null) return;
                      setModal(() => layoutId = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    def?.descricao ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final nome = nomeCtrl.text.trim();
                      if (nome.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Informe o nome.')),
                        );
                        return;
                      }
                      if (!InvestimentoLayoutCatalog.existe(layoutId)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Selecione um layout válido.'),
                          ),
                        );
                        return;
                      }
                      await _repo.salvar(
                        InvestimentoCarteira(
                          id: item?.id,
                          nome: nome,
                          layout: layoutId,
                          criadoEm: item?.criadoEm ?? DateTime.now(),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nomeCtrl.dispose();
    if (ok == true) await _load();
  }

  Future<void> _excluir(InvestimentoCarteira c) async {
    if (c.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Excluir carteira'),
            content: Text(
              'Isso apaga movimentações e configuração desta carteira. Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    try {
      await _repo.deletar(c.id!);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = Colors.red.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteiras de investimento'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/investimentos/carteiras'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _itens.isEmpty
              ? const Center(child: Text('Nenhuma carteira cadastrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _itens.length,
                  itemBuilder: (_, i) {
                    final c = _itens[i];
                    final layoutTitulo =
                        InvestimentoLayoutCatalog.tituloOuId(c.layout);
                    return Slidable(
                      key: ValueKey(c.id ?? i),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.35,
                        children: [
                          CustomSlidableAction(
                            onPressed: (_) => _openForm(item: c),
                            backgroundColor: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.edit,
                              size: 28,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          CustomSlidableAction(
                            onPressed: (_) {
                              if (c.id == 1) return;
                              _excluir(c);
                            },
                            backgroundColor:
                                c.id == 1 ? Colors.grey.shade400 : danger,
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              Icons.delete,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance_wallet_outlined),
                          title: Text(c.nome),
                          subtitle: Text(
                            'Layout: $layoutTitulo • ${_fmt.format(c.criadoEm)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _abrirCarteira(c),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
