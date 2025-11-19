// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/pages/lancamento/lancamento_form_result.dart';

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
  late Categoria _categoria;

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
      _categoria = l.categoria;
      _parcelado = (l.parcelaTotal ?? 1) > 1;
      _qtdParcelasController.text = (l.parcelaTotal ?? 1).toString();
    } else {
      _data = widget.dataInicial ?? DateTime.now();
      _pago = false;
      _formaPagamento = FormaPagamento.values.first;
      _categoria = Categoria.values.first;
      _parcelado = false;
      _qtdParcelasController.text = '1';
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

    final base = Lancamento(
      id: widget.lancamento?.id,
      valor: valor,
      descricao: _descricaoController.text.trim(),
      formaPagamento: _formaPagamento,
      dataHora: _data,
      pagamentoFatura: widget.lancamento?.pagamentoFatura ?? false,
      pago: _pago,
      dataPagamento: _pago ? (widget.lancamento?.dataPagamento ?? agora) : null,
      categoria: _categoria,
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

              DropdownButtonFormField<Categoria>(
                value: _categoria,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items:
                    Categoria.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(_labelEnum(c)),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _categoria = v);
                },
              ),

              const SizedBox(height: 16),
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
