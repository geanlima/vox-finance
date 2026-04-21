// ignore_for_file: deprecated_member_use, control_flow_in_finally

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/categoria_personalizada.dart';
import 'package:vox_finance/ui/data/models/subcategoria_personalizada.dart';
import 'package:vox_finance/ui/data/modules/categorias/categoria_personalizada_repository.dart';
import 'package:vox_finance/ui/data/modules/categorias/subcategoria_personalizada_repository.dart';
import 'package:vox_finance/ui/pages/lancamento/lancamento_form_result.dart';
import 'package:vox_finance/ui/core/layout/list_scroll_padding.dart';

class LancamentoFormPage extends StatefulWidget {
  final Lancamento? lancamento;
  final DateTime? dataInicial;
  final bool isFuturo;

  const LancamentoFormPage({
    super.key,
    this.lancamento,
    this.dataInicial,
    this.isFuturo = false,
  });

  @override
  State<LancamentoFormPage> createState() => _LancamentoFormPageState();
}

class _LancamentoFormPageState extends State<LancamentoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _qtdParcelasController = TextEditingController(text: '1');

  late DateTime _data;
  bool _pago = false;
  bool _parcelado = false;

  late FormaPagamento _formaPagamento;
  CategoriaPersonalizada? _categoriaSel;
  SubcategoriaPersonalizada? _subcategoriaSel;
  List<CategoriaPersonalizada> _categorias = [];
  List<SubcategoriaPersonalizada> _subcategorias = [];
  bool _carregandoCategorias = false;

  final _catRepo = CategoriaPersonalizadaRepository();
  final _subRepo = SubcategoriaPersonalizadaRepository();

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();

    if (widget.lancamento != null) {
      final l = widget.lancamento!;
      _descricaoController.text = l.descricao;
      _valorController.text = l.valor.toStringAsFixed(2);
      _data = l.dataHora;
      _pago = l.pago;
      _formaPagamento = l.formaPagamento;
      _parcelado = (l.parcelaTotal ?? 1) > 1;
      _qtdParcelasController.text = (l.parcelaTotal ?? 1).toString();
    } else {
      _data = widget.dataInicial ?? DateTime.now();
      _pago = false;
      _formaPagamento = FormaPagamento.values.first;
      _parcelado = false;
      _qtdParcelasController.text = '1';
    }

    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    setState(() => _carregandoCategorias = true);
    try {
      // nesta tela, usamos o cadastro de categorias personalizadas (despesa)
      final cats = await _catRepo.listarPorTipo(TipoMovimento.despesa);
      if (!mounted) return;
      setState(() => _categorias = cats);

      final existente = widget.lancamento;
      final idCat = existente?.idCategoriaPersonalizada;
      if (idCat != null) {
        try {
          _categoriaSel = _categorias.firstWhere((c) => c.id == idCat);
        } catch (_) {
          _categoriaSel = null;
        }
      } else if (_categoriaSel == null && _categorias.isNotEmpty) {
        _categoriaSel = _categorias.first;
      }

      await _carregarSubcategorias();
    } finally {
      if (!mounted) return;
      setState(() => _carregandoCategorias = false);
    }
  }

  Future<void> _carregarSubcategorias() async {
    final cat = _categoriaSel;
    if (cat?.id == null) {
      if (!mounted) return;
      setState(() {
        _subcategorias = [];
        _subcategoriaSel = null;
      });
      return;
    }

    final subs = await _subRepo.listarPorCategoria(cat!.id!);
    if (!mounted) return;
    setState(() => _subcategorias = subs);

    final existente = widget.lancamento;
    final idSub = existente?.idSubcategoriaPersonalizada;
    if (idSub != null) {
      try {
        _subcategoriaSel = _subcategorias.firstWhere((s) => s.id == idSub);
      } catch (_) {
        _subcategoriaSel = null;
      }
    } else {
      _subcategoriaSel = null;
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _qtdParcelasController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selecionada != null) {
      setState(() => _data = selecionada);
    }
  }

  String _labelEnum(Object e) {
    final s = e.toString();
    final idx = s.indexOf('.');
    return idx >= 0 ? s.substring(idx + 1) : s;
  }

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

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    final valor =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;

    int qtdParcelas = 1;
    if (_parcelado) {
      qtdParcelas = int.tryParse(_qtdParcelasController.text.trim()) ?? 1;
      if (qtdParcelas < 2) qtdParcelas = 2;
    }

    final agora = DateTime.now();

    final catSel = _categoriaSel;
    if (catSel == null) return;

    final base = Lancamento(
      id: widget.lancamento?.id,
      valor: valor,
      descricao: _descricaoController.text.trim(),
      formaPagamento: _formaPagamento,
      dataHora: _data,
      pagamentoFatura: widget.lancamento?.pagamentoFatura ?? false,
      pago: _pago,
      dataPagamento: _pago ? (widget.lancamento?.dataPagamento ?? agora) : null,
      categoria: _categoriaEnumFromNome(catSel.nome),
      idCategoriaPersonalizada: catSel.id,
      idSubcategoriaPersonalizada: _subcategoriaSel?.id,
      grupoParcelas: widget.lancamento?.grupoParcelas,
      parcelaNumero: widget.lancamento?.parcelaNumero,
      parcelaTotal: _parcelado ? qtdParcelas : 1,
    );

    final result = LancamentoFormResult(
      lancamentoBase: base,
      qtdParcelas: qtdParcelas,
    );

    Navigator.pop(context, result); // 👈 DEVOLVE O RESULT
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.lancamento != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdicao ? 'Editar Lançamento' : 'Novo Lançamento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
      padding: EdgeInsets.only(bottom: listScrollBottomInset(context)),
            children: [
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe a descrição';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Valor'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o valor';
                  }
                  final v = double.tryParse(value.replaceAll(',', '.'));
                  if (v == null) return 'Valor inválido';
                  if (v <= 0) return 'Valor deve ser maior que zero';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<FormaPagamento>(
                value: _formaPagamento,
                decoration: const InputDecoration(
                  labelText: 'Forma de pagamento',
                  border: OutlineInputBorder(),
                ),
                items:
                    FormaPagamento.values
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(_labelEnum(f)),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _formaPagamento = v);
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<CategoriaPersonalizada>(
                value: _categoriaSel,
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  border: const OutlineInputBorder(),
                  helperText:
                      _carregandoCategorias
                          ? 'Carregando categorias...'
                          : _categorias.isEmpty
                          ? 'Nenhuma categoria cadastrada.'
                          : null,
                ),
                items:
                    _categorias
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.nome),
                          ),
                        )
                        .toList(),
                validator: (v) => v == null ? 'Selecione a categoria.' : null,
                onChanged: _categorias.isEmpty
                    ? null
                    : (v) async {
                        setState(() {
                          _categoriaSel = v;
                          _subcategoriaSel = null;
                          _subcategorias = [];
                        });
                        await _carregarSubcategorias();
                      },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<SubcategoriaPersonalizada>(
                value: _subcategoriaSel,
                decoration: InputDecoration(
                  labelText: 'Subcategoria',
                  border: const OutlineInputBorder(),
                  helperText:
                      _categoriaSel == null
                          ? 'Selecione uma categoria para ver as subcategorias.'
                          : _subcategorias.isEmpty
                          ? 'Sem subcategorias para esta categoria.'
                          : null,
                ),
                items:
                    _subcategorias
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.nome),
                          ),
                        )
                        .toList(),
                validator: (v) {
                  if (_subcategorias.isNotEmpty && v == null) {
                    return 'Selecione a subcategoria.';
                  }
                  return null;
                },
                onChanged: _subcategorias.isEmpty
                    ? null
                    : (v) => setState(() => _subcategoriaSel = v),
              ),
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(_dateFormat.format(_data)),
                ),
              ),

              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Lançamento parcelado?'),
                value: _parcelado,
                onChanged: (v) {
                  setState(() => _parcelado = v);
                },
              ),
              if (_parcelado) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _qtdParcelasController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantidade de parcelas',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_parcelado) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a quantidade de parcelas';
                    }
                    final n = int.tryParse(value.trim());
                    if (n == null || n < 2) {
                      return 'Informe pelo menos 2 parcelas';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Já está pago?'),
                value: _pago,
                onChanged: (v) {
                  if (v != null) setState(() => _pago = v);
                },
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvar,
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
