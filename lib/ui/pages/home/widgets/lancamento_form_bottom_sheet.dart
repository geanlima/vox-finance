// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/utils/currency_input_formatter.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/cartao_credito.dart';
import 'package:vox_finance/ui/data/models/conta_bancaria.dart';
import 'package:vox_finance/ui/data/service/db_service.dart';

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
  });

  @override
  State<LancamentoFormBottomSheet> createState() =>
      _LancamentoFormBottomSheetState();
}

class _LancamentoFormBottomSheetState extends State<LancamentoFormBottomSheet> {
  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late TextEditingController _qtdParcelasController;

  FormaPagamento? _formaSelecionada;
  bool _pagamentoFatura = false;
  bool _pago = true;
  late DateTime _dataLancamento;

  Categoria? _categoriaSelecionada;
  bool _parcelado = false;

  CartaoCredito? _cartaoSelecionado;
  ContaBancaria? _contaSelecionada;

  late List<CartaoCredito> _cartoesFiltrados;

  Lancamento? get _existente => widget.existente;
  List<CartaoCredito> get _cartoes => widget.cartoes;
  List<ContaBancaria> get _contas => widget.contas;

  @override
  void initState() {
    super.initState();

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

    // Categoria
    _categoriaSelecionada = _existente?.categoria;
    if (_existente == null && _categoriaSelecionada == null) {
      final baseDesc = widget.descricaoInicial ?? _existente?.descricao ?? '';
      if (baseDesc.trim().isNotEmpty) {
        _categoriaSelecionada = CategoriaService.fromDescricao(baseDesc);
      }
    }

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
  }

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    _qtdParcelasController.dispose();
    super.dispose();
  }

  // ============================================================
  //  REGRAS DE CARTÃO (extraídas da Home)
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

  // ============================================================
  //  BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: StatefulBuilder(
        builder: (context, setModalState) {
          void _recalcularCartoes() {
            _cartoesFiltrados = _filtrarCartoes(
              _formaSelecionada,
              _pagamentoFatura,
            );

            if (_cartaoSelecionado != null &&
                !_cartoesFiltrados.any((c) => c.id == _cartaoSelecionado!.id)) {
              _cartaoSelecionado = null;
            }
          }

          // recalcula sempre no início do build
          _recalcularCartoes();

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

          final bool deveMostrarSecaoCartao =
              _pagamentoFatura ||
              _formaSelecionada == FormaPagamento.debito ||
              _formaSelecionada == FormaPagamento.credito;

          final bool deveMostrarSecaoConta =
              _formaSelecionada == FormaPagamento.pix ||
              _formaSelecionada == FormaPagamento.boleto ||
              _formaSelecionada == FormaPagamento.transferencia;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                TextField(
                  controller: _valorController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Descrição
                TextField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex: Mercado, Uber, Almoço...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Categoria
                DropdownButtonFormField<Categoria>(
                  value: _categoriaSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      Categoria.values.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(CategoriaService.toName(c)),
                        );
                      }).toList(),
                  onChanged: (nova) {
                    setModalState(() {
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
                    setModalState(() {
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
                    setModalState(() {
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
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
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
                        setModalState(() {
                          _cartaoSelecionado = novoCartao;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Seção conta
                if (deveMostrarSecaoConta) ...[
                  const SizedBox(height: 8),
                  if (_contas.isEmpty) ...[
                    const Text(
                      'Nenhuma conta bancária ativa.\n'
                      'Cadastre em: Menu → Contas bancárias.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
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
                        setModalState(() {
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
                    setModalState(() {
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
                      setModalState(() {
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
                      setModalState(() {
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
                const SizedBox(height: 16),

                // Botões
                Row(
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
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  //  SALVAR
  // ============================================================

  Future<void> _salvar() async {
    double? valor;
    try {
      valor = CurrencyInputFormatter.parse(_valorController.text);
    } catch (_) {
      valor = null;
    }

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    if (_formaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a forma de pagamento.')),
      );
      return;
    }

    if (_categoriaSelecionada == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione a categoria.')));
      return;
    }

    // Recalcula cartões antes da validação final
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

    final descricao =
        _descricaoController.text.trim().isNotEmpty
            ? _descricaoController.text.trim()
            : 'Sem descrição';

    final categoria = _categoriaSelecionada!;

    final Lancamento lanc =
        _existente != null
            ? _existente!.copyWith(
              valor: valor,
              descricao: descricao,
              formaPagamento: _formaSelecionada!,
              dataHora: _dataLancamento,
              pagamentoFatura: _pagamentoFatura,
              categoria: categoria,
              pago: _pago,
              dataPagamento:
                  _pago ? (_existente!.dataPagamento ?? DateTime.now()) : null,
              idCartao: _cartaoSelecionado?.id,
              idConta: _contaSelecionada?.id,
            )
            : Lancamento(
              valor: valor,
              descricao: descricao,
              formaPagamento: _formaSelecionada!,
              dataHora: _dataLancamento,
              pagamentoFatura: _pagamentoFatura,
              categoria: categoria,
              pago: _pago,
              dataPagamento: _pago ? DateTime.now() : null,
              idCartao: _cartaoSelecionado?.id,
              idConta: _contaSelecionada?.id,
            );

    // Parcelado x simples
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

      final base = lanc.copyWith(
        grupoParcelas: null,
        parcelaNumero: null,
        parcelaTotal: null,
      );

      await widget.dbService.salvarLancamentosParceladosFuturos(base, qtd);
    } else {
      await widget.dbService.salvarLancamento(lanc);
    }

    await widget.onSaved();
    Navigator.pop(context);
  }
}
