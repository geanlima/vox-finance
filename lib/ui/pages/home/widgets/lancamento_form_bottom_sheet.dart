// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_field, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/regra_cartao_parcelado_service.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';

// 🔹 modelo + repositório de categorias personalizadas
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';

import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

// 👇 service de outras compras parceladas
import 'package:vox_finance/ui/core/service/regra_outra_compra_parcelada_service.dart';

class LancamentoFormBottomSheet extends StatefulWidget {
  final Lancamento? existente;
  final double? valorInicial;
  final String? descricaoInicial;
  final FormaPagamento? formaInicial;
  final bool? pagamentoFaturaInicial;

  final DateTime dataSelecionada;
  final NumberFormat currency;
  final DateFormat dateDiaFormat;

  final DbService dbService;
  final List<CartaoCredito> cartoes;
  final List<ContaBancaria> contas;

  final TipoMovimento? tipoInicial;

  /// Chamado depois de salvar (para a Home recarregar a tela)
  final Future<void> Function() onSaved;

  const LancamentoFormBottomSheet({
    super.key,
    this.existente,
    this.valorInicial,
    this.descricaoInicial,
    this.formaInicial,
    this.pagamentoFaturaInicial,
    required this.dataSelecionada,
    required this.currency,
    required this.dateDiaFormat,
    required this.dbService,
    required this.cartoes,
    required this.contas,
    required this.onSaved,
    this.tipoInicial,
  });

  @override
  State<LancamentoFormBottomSheet> createState() =>
      _LancamentoFormBottomSheetState();
}

class _LancamentoFormBottomSheetState extends State<LancamentoFormBottomSheet> {
  // 🔴 chave do formulário
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late TextEditingController _qtdParcelasController;

  final LancamentoRepository _repositoryLancamento = LancamentoRepository();
  final _catPersRepo = CategoriaPersonalizadaRepository();

  // 👇 service para criar parcelas + contas a pagar
  final RegraOutraCompraParceladaService _regraOutraCompra =
      RegraOutraCompraParceladaService();

  FormaPagamento? _formaSelecionada;
  bool _pagamentoFatura = false;
  bool _pago = true;
  late DateTime _dataLancamento;

  /// Agora a categoria selecionada SEMPRE vem da tabela categorias_personalizadas
  CategoriaPersonalizada? _categoriaSelecionada;

  bool _parcelado = false;

  CartaoCredito? _cartaoSelecionado;
  ContaBancaria? _contaSelecionada;

  late List<CartaoCredito> _cartoesFiltrados;
  List<CategoriaPersonalizada> _categoriasPersonalizadas = [];

  Lancamento? get _existente => widget.existente;
  List<CartaoCredito> get _cartoes => widget.cartoes;
  List<ContaBancaria> get _contas => widget.contas;

  // ⭐ estado do tipo de movimento (Receita / Despesa)
  late TipoMovimento _tipoMovimento;

  @override
  void initState() {
    super.initState();

    _tipoMovimento =
        widget.existente?.tipoMovimento ??
        widget.tipoInicial ??
        TipoMovimento.despesa; // padrão

    // Valor inicial
    _valorController = TextEditingController(
      text:
          _existente != null
              ? widget.currency.format(_existente!.valor)
              : (widget.valorInicial != null
                  ? widget.currency.format(widget.valorInicial)
                  : ''),
    );

    // Descrição inicial
    _descricaoController = TextEditingController(
      text: _existente?.descricao ?? (widget.descricaoInicial ?? ''),
    );

    _formaSelecionada =
        _existente?.formaPagamento ??
        (widget.formaInicial ?? FormaPagamento.credito);

    _pagamentoFatura =
        _existente?.pagamentoFatura ?? (widget.pagamentoFaturaInicial ?? false);

    _pago = _existente?.pago ?? true;
    _dataLancamento = _existente?.dataHora ?? widget.dataSelecionada;

    _parcelado = false;
    _qtdParcelasController = TextEditingController(text: '2');

    // Cartão selecionado (se já vier do lançamento)
    if (_existente?.idCartao != null && _cartoes.isNotEmpty) {
      try {
        _cartaoSelecionado = _cartoes.firstWhere(
          (c) => c.id == _existente!.idCartao,
        );
      } catch (_) {
        _cartaoSelecionado = null;
      }
    }

    // Conta bancária selecionada (se já vier do lançamento)
    if (_existente?.idConta != null && _contas.isNotEmpty) {
      try {
        _contaSelecionada = _contas.firstWhere(
          (c) => c.id == _existente!.idConta,
        );
      } catch (_) {
        _contaSelecionada = null;
      }
    }

    _cartoesFiltrados = _filtrarCartoes(_formaSelecionada, _pagamentoFatura);

    // 🔹 carrega categorias personalizadas para o tipo atual
    _carregarCategoriasPersonalizadas();
  }

  Future<void> _carregarCategoriasPersonalizadas() async {
    final lista = await _catPersRepo.listarPorTipo(_tipoMovimento);

    if (!mounted) return;

    setState(() {
      _categoriasPersonalizadas = lista;

      // se estiver editando e o lançamento já tiver id_categoria_personalizada
      if (_existente?.idCategoriaPersonalizada != null) {
        final idCat = _existente!.idCategoriaPersonalizada!;
        try {
          _categoriaSelecionada = _categoriasPersonalizadas.firstWhere(
            (c) => c.id == idCat,
          );
        } catch (_) {
          _categoriaSelecionada = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _qtdParcelasController.dispose();
    super.dispose();
  }

  // ============================================================
  //  REGRAS DE CARTÃO
  // ============================================================

  List<CartaoCredito> _filtrarCartoes(
    FormaPagamento? forma,
    bool pagamentoFatura,
  ) {
    if (pagamentoFatura) {
      // Pagamento de fatura → sempre cartão crédito ou ambos
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    if (forma == FormaPagamento.debito) {
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.debito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    if (forma == FormaPagamento.credito) {
      return _cartoes.where((c) {
        return c.tipo == TipoCartao.credito || c.tipo == TipoCartao.ambos;
      }).toList();
    }

    return const [];
  }

  void _recalcularCartoes() {
    _cartoesFiltrados = _filtrarCartoes(_formaSelecionada, _pagamentoFatura);

    if (_cartaoSelecionado != null &&
        !_cartoesFiltrados.any((c) => c.id == _cartaoSelecionado!.id)) {
      _cartaoSelecionado = null;
    }
  }

  String _labelCartao() {
    if (_pagamentoFatura) {
      return 'Cartão cuja fatura está sendo paga';
    }
    if (_formaSelecionada == FormaPagamento.debito) {
      return 'Cartão de débito';
    }
    if (_formaSelecionada == FormaPagamento.credito) {
      return 'Cartão de crédito';
    }
    return 'Cartão';
  }

  // ============================================================
  //  BUILD – com conteúdo rolando e rodapé fixo
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets;
    final sysPadding = mq.padding;

    // recalcula sempre que builda
    _recalcularCartoes();

    final bool deveMostrarSecaoCartao =
        _pagamentoFatura ||
        _formaSelecionada == FormaPagamento.debito ||
        _formaSelecionada == FormaPagamento.credito;

    final bool deveMostrarSecaoConta =
        _formaSelecionada == FormaPagamento.pix ||
        _formaSelecionada == FormaPagamento.boleto ||
        _formaSelecionada == FormaPagamento.transferencia;

    return SafeArea(
      top: false,
      child: Padding(
        // faz o sheet subir junto com o teclado
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // =================== CONTEÚDO ROLÁVEL ===================
              Expanded(
                // Form envolvendo todo o conteúdo
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "pegador"
                        Center(
                          child: Container(
                            width: 50,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            Icon(_existente != null ? Icons.edit : Icons.add),
                            const SizedBox(width: 8),
                            Text(
                              _existente != null
                                  ? 'Editar lançamento'
                                  : 'Novo lançamento',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Valor
                        TextFormField(
                          controller: _valorController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Valor',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            try {
                              final v = CurrencyInputFormatter.parse(
                                value ?? '',
                              );
                              if (v <= 0) {
                                return 'Informe um valor válido.';
                              }
                            } catch (_) {
                              return 'Informe um valor válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Descrição (opcional)
                        TextField(
                          controller: _descricaoController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Ex: Mercado, Uber, Almoço...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tipo de movimento (Receita / Despesa)
                        Text(
                          'Tipo de movimento',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Despesa'),
                              selected: _tipoMovimento == TipoMovimento.despesa,
                              onSelected: (sel) {
                                if (!sel) return;
                                setState(() {
                                  _tipoMovimento = TipoMovimento.despesa;
                                  _categoriaSelecionada = null;
                                });
                                _carregarCategoriasPersonalizadas();
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Receita'),
                              selected: _tipoMovimento == TipoMovimento.receita,
                              onSelected: (sel) {
                                if (!sel) return;
                                setState(() {
                                  _tipoMovimento = TipoMovimento.receita;
                                  _categoriaSelecionada = null;
                                });
                                _carregarCategoriasPersonalizadas();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Categoria (somente tabela categorias_personalizadas)
                        // Categoria (somente tabela categorias_personalizadas)
                        DropdownButtonFormField<CategoriaPersonalizada>(
                          value: _categoriaSelecionada,
                          decoration: InputDecoration(
                            labelText: 'Categoria',
                            border: const OutlineInputBorder(),
                            helperText:
                                _categoriasPersonalizadas.isEmpty
                                    ? 'Categorias ainda não carregadas ou não cadastradas.'
                                    : null,
                          ),
                          validator: (CategoriaPersonalizada? value) {
                            if (_categoriasPersonalizadas.isNotEmpty &&
                                value == null) {
                              return 'Selecione a categoria.';
                            }
                            return null;
                          },
                          items:
                              _categoriasPersonalizadas
                                  .map(
                                    (cat) => DropdownMenuItem<
                                      CategoriaPersonalizada
                                    >(
                                      value: cat,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.category, size: 16),
                                          const SizedBox(width: 6),
                                          Text(cat.nome),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              _categoriasPersonalizadas.isEmpty
                                  ? null
                                  : (CategoriaPersonalizada? nova) {
                                    setState(() {
                                      _categoriaSelecionada = nova;
                                    });
                                  },
                        ),

                        const SizedBox(height: 12),

                        // Forma de pagamento
                        DropdownButtonFormField<FormaPagamento>(
                          value: _formaSelecionada,
                          decoration: const InputDecoration(
                            labelText: 'Forma de pagamento',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null) {
                              return 'Selecione a forma de pagamento.';
                            }
                            return null;
                          },
                          items:
                              FormaPagamento.values.map((f) {
                                return DropdownMenuItem(
                                  value: f,
                                  child: Row(
                                    children: [
                                      Icon(f.icon, size: 18),
                                      const SizedBox(width: 8),
                                      Text(f.label),
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (novo) {
                            setState(() {
                              _formaSelecionada = novo;
                              _recalcularCartoes();
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Pagamento de fatura
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pagamento de fatura de cartão'),
                          value: _pagamentoFatura,
                          onChanged: (v) {
                            setState(() {
                              _pagamentoFatura = v ?? false;
                              _recalcularCartoes();
                            });
                          },
                        ),

                        // Seção cartão
                        if (deveMostrarSecaoCartao) ...[
                          const SizedBox(height: 8),
                          if (_cartoes.isEmpty) ...[
                            const Text(
                              'Nenhum cartão cadastrado.\n'
                              'Cadastre em: Menu → Cartões.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ] else if (_cartoesFiltrados.isEmpty) ...[
                            Text(
                              _pagamentoFatura
                                  ? 'Nenhum cartão de crédito (ou ambos) cadastrado para vincular a fatura.'
                                  : 'Nenhum cartão compatível com essa forma de pagamento.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ] else ...[
                            DropdownButtonFormField<CartaoCredito>(
                              value: _cartaoSelecionado,
                              decoration: InputDecoration(
                                labelText: _labelCartao(),
                                border: const OutlineInputBorder(),
                              ),
                              items:
                                  _cartoesFiltrados.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(c.label),
                                    );
                                  }).toList(),
                              onChanged: (novoCartao) {
                                setState(() {
                                  _cartaoSelecionado = novoCartao;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],

                        // Seção conta bancária
                        if (deveMostrarSecaoConta) ...[
                          const SizedBox(height: 8),
                          if (_contas.isEmpty) ...[
                            const Text(
                              'Nenhuma conta bancária ativa.\n'
                              'Cadastre em: Menu → Contas bancárias.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ] else ...[
                            DropdownButtonFormField<ContaBancaria>(
                              value: _contaSelecionada,
                              decoration: const InputDecoration(
                                labelText: 'Conta bancária',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  _contas.map((c) {
                                    final texto =
                                        '${c.descricao} ${c.banco != null && c.banco!.isNotEmpty ? "(${c.banco})" : ""}';
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(texto),
                                    );
                                  }).toList(),
                              onChanged: (novaConta) {
                                setState(() {
                                  _contaSelecionada = novaConta;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],

                        // Já está pago
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Já está pago'),
                          subtitle: const Text(
                            'Desmarque para deixar como lançamento futuro/pendente.',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _pago,
                          onChanged: (v) {
                            setState(() {
                              _pago = v ?? false;
                            });
                          },
                        ),

                        // Parcelamento (somente novo)
                        if (_existente == null) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Lançamento parcelado?'),
                            value: _parcelado,
                            onChanged: (v) {
                              setState(() {
                                _parcelado = v;
                              });
                            },
                          ),
                          if (_parcelado) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _qtdParcelasController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantidade de parcelas',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 12),

                        // Data
                        InkWell(
                          onTap: () async {
                            final novaData = await showDatePicker(
                              context: context,
                              initialDate: _dataLancamento,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (novaData != null) {
                              setState(() {
                                _dataLancamento = DateTime(
                                  novaData.year,
                                  novaData.month,
                                  novaData.day,
                                  _dataLancamento.hour,
                                  _dataLancamento.minute,
                                );
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Data: ${widget.dateDiaFormat.format(_dataLancamento)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              // =================== RODAPÉ FIXO COM BOTÕES ===================
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  8 + sysPadding.bottom, // fica acima da barra do sistema
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _salvar,
                      child: Text(
                        _existente != null ? 'Salvar alterações' : 'Salvar',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  SALVAR
  // ============================================================

  Future<void> _salvar() async {
  // 1) Valida o formulário (campos obrigatórios)
  final formOk = _formKey.currentState?.validate() ?? false;
  if (!formOk) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrija os campos destacados antes de salvar.'),
      ),
    );
    return;
  }

  // Forma de pagamento não deveria ser nula por causa do validator,
  // mas garantimos aqui por segurança.
  if (_formaSelecionada == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecione a forma de pagamento.')),
    );
    return;
  }

  // 2) Valor
  late final double valor;
  try {
    valor = CurrencyInputFormatter.parse(_valorController.text);
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Valor inválido.')),
    );
    return;
  }

  // 3) Regras de cartão
  _cartoesFiltrados = _filtrarCartoes(_formaSelecionada, _pagamentoFatura);
  final bool temCartaoCompativel = _cartoesFiltrados.isNotEmpty;

  final bool precisaCartao =
      (_formaSelecionada == FormaPagamento.credito &&
          temCartaoCompativel &&
          !_pagamentoFatura) ||
      (_pagamentoFatura && temCartaoCompativel);

  if (precisaCartao && _cartaoSelecionado == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _pagamentoFatura
              ? 'Selecione qual cartão você está pagando a fatura.'
              : 'Selecione o cartão de crédito usado.',
        ),
      ),
    );
    return;
  }

  // 4) Regras de conta bancária
  final bool precisaContaBancaria =
      (_formaSelecionada == FormaPagamento.pix ||
          _formaSelecionada == FormaPagamento.boleto ||
          _formaSelecionada == FormaPagamento.transferencia) &&
      _contas.isNotEmpty;

  if (precisaContaBancaria && _contaSelecionada == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecione a conta bancária utilizada.')),
    );
    return;
  }

  // 5) Categoria (sempre da tabela categorias_personalizadas)
  final catSel = _categoriaSelecionada;
  if (catSel == null) {
    // Em teoria o validator do combo já garante, mas deixo por segurança
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selecione a categoria.')),
    );
    return;
  }

  // Descrição
  String descricao = _descricaoController.text.trim();
  if (descricao.isEmpty || descricao == 'Sem descrição') {
    descricao = catSel.nome;
  }

  // Enum "antigo" só para compatibilidade
  final Categoria categoriaEnum = _categoriaEnumFromNome(catSel.nome);

  // Código da categoria na tabela
  final int? idCategoriaPersonalizada = catSel.id;

  // 6) Monta o objeto Lancamento
  final Lancamento lanc;
  if (_existente != null) {
    lanc = _existente!.copyWith(
      valor: valor,
      descricao: descricao,
      formaPagamento: _formaSelecionada!,
      dataHora: _dataLancamento,
      pagamentoFatura: _pagamentoFatura,
      categoria: categoriaEnum,
      pago: _pago,
      dataPagamento:
          _pago ? (_existente!.dataPagamento ?? DateTime.now()) : null,
      idCartao: _cartaoSelecionado?.id,
      idConta: _contaSelecionada?.id,
      tipoMovimento: _tipoMovimento,
      idCategoriaPersonalizada: idCategoriaPersonalizada,
    );
  } else {
    lanc = Lancamento(
      valor: valor,
      descricao: descricao,
      formaPagamento: _formaSelecionada!,
      dataHora: _dataLancamento,
      pagamentoFatura: _pagamentoFatura,
      categoria: categoriaEnum,
      pago: _pago,
      dataPagamento: _pago ? DateTime.now() : null,
      idCartao: _cartaoSelecionado?.id,
      idConta: _contaSelecionada?.id,
      tipoMovimento: _tipoMovimento,
      idCategoriaPersonalizada: idCategoriaPersonalizada,
    );
  }

  // 7) Parcelado x simples
  if (_existente == null && _parcelado) {
    final qtd = int.tryParse(_qtdParcelasController.text) ?? 1;

    if (qtd < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe uma quantidade de parcelas maior ou igual a 2.',
          ),
        ),
      );
      return;
    }

    // base SEM info de parcela; service completa e força NÃO pago
    final base = lanc.copyWith(
      grupoParcelas: null,
      parcelaNumero: null,
      parcelaTotal: null,
    );

    if (_formaSelecionada == FormaPagamento.credito) {
      final regraCartaoParceladoService = RegraCartaoParceladoService();

      regraCartaoParceladoService.processarCompraParcelada(
        compraBase: base,
        qtdParcelas: qtd,
      );
    } else {
      await _regraOutraCompra.criarParcelasNaoPagas(base, qtd);
    }
  } else {
    await _repositoryLancamento.salvar(lanc);
  }

  // 8) Atualiza tela e fecha modal
  await widget.onSaved();
  Navigator.pop(context);
}


  /// Mapeia o NOME da categoria da tabela para o enum antigo,
  /// para manter compatibilidade com telas/gráficos que usam Categoria.
  Categoria _categoriaEnumFromNome(String nome) {
    switch (nome) {
      case 'Alimentação':
        return Categoria.alimentacao;
      case 'Educação':
        return Categoria.educacao;
      case 'Família':
        return Categoria.familia;
      case 'Finanças Pessoais':
        return Categoria.financasPessoais;
      case 'Impostos e Taxas':
        return Categoria.impostosETaxas;
      case 'Lazer e Entretenimento':
        return Categoria.lazerEEntretenimento;
      case 'Moradia':
        return Categoria.moradia;
      case 'Presentes e Doações':
        return Categoria.presentesEDoacoes;
      case 'Saúde':
        return Categoria.saude;
      case 'Seguros':
        return Categoria.seguros;
      case 'Tecnologia':
        return Categoria.tecnologia;
      case 'Transporte':
        return Categoria.transporte;
      case 'Vestuário':
        return Categoria.vestuario;
      case 'Outros':
      default:
        return Categoria.outros;
    }
  }
}
