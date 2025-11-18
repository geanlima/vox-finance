// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:vox_finance/ui/data/sevice/isar_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

class LancamentoFuturoPage extends StatefulWidget {
  const LancamentoFuturoPage({super.key});

  @override
  State<LancamentoFuturoPage> createState() => _LancamentoFuturoPageState();
}

class _LancamentoFuturoPageState extends State<LancamentoFuturoPage> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorTotalController = TextEditingController(text: '');
  final _parcelasController = TextEditingController(text: '1');

  final _isarService = IsarService();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  DateTime _primeiraData = DateTime.now();
  FormaPagamento _forma = FormaPagamento.credito;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorTotalController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final nova = await showDatePicker(
      context: context,
      initialDate: _primeiraData,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nova != null) {
      setState(() {
        _primeiraData = nova;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final desc = _descricaoController.text.trim();
    final valorTotal = double.tryParse(
          _valorTotalController.text
              .replaceAll('.', '')
              .replaceAll(',', '.'),
        ) ??
        0;
    final qtdParcelas =
        int.tryParse(_parcelasController.text.trim()) ?? 1;

    if (desc.isEmpty || valorTotal <= 0 || qtdParcelas <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe descrição, valor total e quantidade de parcelas válidos.',
          ),
        ),
      );
      return;
    }

    await _isarService.criarLancamentosFuturosParcelados(
      descricao: desc,
      valorTotal: valorTotal,
      quantidadeParcelas: qtdParcelas,
      primeiraData: _primeiraData,
      formaPagamento: _forma,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lançamentos futuros criados com sucesso.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamento Futuro Parcelado'),
      ),
      drawer: const AppDrawer(currentRoute: '/lancamentos-futuros'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Planejar compra/conta parcelada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: TV LG, Notebook, Seguro, etc.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Informe a descrição'
                        : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _valorTotalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor total',
                  hintText: 'Ex: 2400,00',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Informe o valor total'
                        : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _parcelasController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de parcelas',
                  hintText: 'Ex: 1, 6, 12...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Informe a quantidade de parcelas'
                        : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<FormaPagamento>(
                value: _forma,
                decoration: const InputDecoration(
                  labelText: 'Forma de pagamento',
                  border: OutlineInputBorder(),
                ),
                items: FormaPagamento.values.map((f) {
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
                onChanged: (v) {
                  setState(() {
                    _forma = v ?? FormaPagamento.credito;
                  });
                },
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _selecionarData,
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
                      const Icon(Icons.event, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Primeira parcela: ${_dateFormat.format(_primeiraData)}',
                        style: TextStyle(color: colors.onBackground),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
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
                    child: const Text('Criar lançamentos'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
