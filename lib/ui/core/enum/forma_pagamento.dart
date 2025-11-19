import 'package:flutter/material.dart';

enum FormaPagamento {
  credito,
  debito,
  pix,
  dinheiro,
  boleto,
  transferencia,
  cheque,
  outros,
}

extension FormaPagamentoExt on FormaPagamento {
  String get label {
    switch (this) {
      case FormaPagamento.credito:
        return 'Crédito';
      case FormaPagamento.debito:
        return 'Débito';
      case FormaPagamento.pix:
        return 'Pix';
      case FormaPagamento.dinheiro:
        return 'Dinheiro';
      case FormaPagamento.boleto:
        return 'Boleto';
      case FormaPagamento.transferencia:
        return 'Transferência';
      case FormaPagamento.cheque:
        return 'Cheque';
      case FormaPagamento.outros:
        return 'Outros';
    }
  }

  IconData get icon {
    switch (this) {
      case FormaPagamento.credito:
        return Icons.credit_card;
      case FormaPagamento.debito:
        return Icons.atm;
      case FormaPagamento.pix:
        return Icons.pix;
      case FormaPagamento.dinheiro:
        return Icons.attach_money;
      case FormaPagamento.boleto:
        return Icons.receipt_long;
      case FormaPagamento.transferencia:
        return Icons.compare_arrows;
      case FormaPagamento.cheque:
        return Icons.description;
      case FormaPagamento.outros:
        return Icons.more_horiz;
    }
  }
}
