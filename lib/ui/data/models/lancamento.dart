import 'package:isar/isar.dart';
import 'package:flutter/material.dart';

part 'lancamento.g.dart';

@collection
class Lancamento {
  Id id = Isar.autoIncrement;

  /// Valor do lançamento
  late double valor;

  /// Descrição (ex: "Mercado", "Uber", "Almoço")
  late String descricao;

  /// Forma de pagamento
  @enumerated
  late FormaPagamento formaPagamento;

  /// Data de referência (pode ser data planejada ou de pagamento)
  late DateTime dataHora;

  /// true quando é pagamento de fatura de cartão
  bool pagamentoFatura = false;

  /// Se o lançamento já foi pago ou ainda está pendente
  bool pago = true;

  /// Data em que foi pago (se pago == true)
  DateTime? dataPagamento;

  /// Categoria (obrigatória para o Isar; use "outros" como fallback)
  @enumerated
  late Categoria categoria;

  /// Se veio de um grupo de parcelas (conta parcelada / lançamento futuro)
  String? grupoParcelas; // identificador do grupo
  int? parcelaNumero;    // número da parcela
  int? parcelaTotal;     // total de parcelas
}

enum Categoria {
  mercado,
  transporte,
  lazer,
  alimentacao,
  saude,
  contas,
  outros,
}

enum FormaPagamento { credito, debito, dinheiro, pix, boleto }

extension FormaPagamentoExt on FormaPagamento {
  String get label {
    switch (this) {
      case FormaPagamento.credito:
        return 'Crédito';
      case FormaPagamento.debito:
        return 'Débito';
      case FormaPagamento.dinheiro:
        return 'Dinheiro';
      case FormaPagamento.pix:
        return 'Pix';
      case FormaPagamento.boleto:
        return 'Boleto';
    }
  }

  IconData get icon {
    switch (this) {
      case FormaPagamento.credito:
        return Icons.credit_card;
      case FormaPagamento.debito:
        return Icons.atm;
      case FormaPagamento.dinheiro:
        return Icons.attach_money;
      case FormaPagamento.pix:
        return Icons.pix;
      case FormaPagamento.boleto:
        return Icons.receipt_long;
    }
  }
}
