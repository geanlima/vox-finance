import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vox_finance/ui/data/sevice/db_service.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';

class ContaPagarForm extends StatefulWidget {
  final ContaPagar? contaExistente;

  const ContaPagarForm({super.key, this.contaExistente});

  @override
  State<ContaPagarForm> createState() => _ContaPagarFormState();
}

class _ContaPagarFormState extends State<ContaPagarForm> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _dbService = DbService();
  DateTime _dataVencimento = DateTime.now();

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final c = widget.contaExistente;
    if (c != null) {
      _descricaoController.text = c.descricao;
      _valorController.text = c.valor.toStringAsFixed(2).replaceAll('.', ',');
      _dataVencimento = c.dataVencimento;
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: _dataVencimento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (novaData != null) {
      setState(() => _dataVencimento = novaData);
    }
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final desc = _descricaoController.text.trim();

    // trata o valor digitado (12,34 / 12.34)
    final valorStr = _valorController.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');

    final valor = double.tryParse(valorStr);

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    // garante que você tem uma data de vencimento válida
    final dataVencimento = _dataVencimento; // sua variável de estado

    // se for edição, reaproveita o objeto;
    // se for novo, cria um com todos os campos obrigatórios
    final bool ehEdicao = widget.contaExistente != null;

    ContaPagar conta;
    if (ehEdicao) {
      conta = widget.contaExistente!;
      conta
        ..descricao = desc
        ..valor = valor
        ..dataVencimento = dataVencimento;
      // grupoParcelas e demais campos são mantidos
    } else {
      final grupo = 'SIMP_${DateTime.now().microsecondsSinceEpoch}';

      conta = ContaPagar(
        descricao: desc,
        valor: valor,
        dataVencimento: dataVencimento,
        pago: false,
        dataPagamento: null,
        parcelaNumero: 1,
        parcelaTotal: 1,
        grupoParcelas: grupo,
      );
    }

    await _dbService.salvarContaPagar(conta);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.contaExistente != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ehEdicao ? Icons.edit : Icons.add),
                  const SizedBox(width: 8),
                  Text(
                    ehEdicao ? 'Editar conta a pagar' : 'Nova conta a pagar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Informe a descrição'
                            : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: 'Ex: 250,00',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Informe o valor'
                            : null,
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
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Vencimento: ${_dateFormat.format(_dataVencimento)}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
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
                    child: Text(ehEdicao ? 'Salvar' : 'Adicionar'),
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
