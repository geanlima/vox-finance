// lib/ui/data/models/lancamento.dart

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';

/// Tipo do movimento financeiro:
/// - receita  -> entra dinheiro
/// - despesa  -> sai dinheiro
enum TipoMovimento { receita, despesa }

extension TipoMovimentoExt on TipoMovimento {
  String get label {
    switch (this) {
      case TipoMovimento.receita:
        return 'Receita';
      case TipoMovimento.despesa:
        return 'Despesa';
    }
  }
}

class Lancamento {
  int? id;
  double valor;
  String descricao;
  FormaPagamento formaPagamento;
  DateTime dataHora;

  /// true = é o lançamento que representa **pagamento de fatura**
  /// false = lançamento normal (compra, gasto, receita, etc)
  bool pagamentoFatura;

  /// se já foi pago / realizado
  bool pago;
  DateTime? dataPagamento;

  Categoria categoria;

  int? idCartao;
  int? idConta;

  /// Grupo para parcelados (mesmo grupo = mesma compra)
  String? grupoParcelas;
  int? parcelaNumero;
  int? parcelaTotal;

  /// ⭐ NOVO: se é receita ou despesa
  TipoMovimento tipoMovimento;

  Lancamento({
    this.id,
    required this.valor,
    required this.descricao,
    required this.formaPagamento,
    required this.dataHora,
    this.pagamentoFatura = false,
    this.pago = false,
    this.dataPagamento,
    this.categoria = Categoria.outros,
    this.idCartao,
    this.idConta,
    this.grupoParcelas,
    this.parcelaNumero,
    this.parcelaTotal,

    /// por padrão tudo que existe hoje continua sendo DESPESA
    this.tipoMovimento = TipoMovimento.despesa,
  });

  // ----------------------------------------------------------
  //  C O P Y W I T H
  // ----------------------------------------------------------
  Lancamento copyWith({
    int? id,
    double? valor,
    String? descricao,
    FormaPagamento? formaPagamento,
    DateTime? dataHora,
    bool? pagamentoFatura,
    bool? pago,
    DateTime? dataPagamento,
    Categoria? categoria,
    int? idCartao,
    int? idConta,
    String? grupoParcelas,
    int? parcelaNumero,
    int? parcelaTotal,
    TipoMovimento? tipoMovimento,
  }) {
    return Lancamento(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      descricao: descricao ?? this.descricao,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      dataHora: dataHora ?? this.dataHora,
      pagamentoFatura: pagamentoFatura ?? this.pagamentoFatura,
      pago: pago ?? this.pago,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      categoria: categoria ?? this.categoria,
      idCartao: idCartao ?? this.idCartao,
      idConta: idConta ?? this.idConta,
      grupoParcelas: grupoParcelas ?? this.grupoParcelas,
      parcelaNumero: parcelaNumero ?? this.parcelaNumero,
      parcelaTotal: parcelaTotal ?? this.parcelaTotal,
      tipoMovimento: tipoMovimento ?? this.tipoMovimento,
    );
  }

  // ----------------------------------------------------------
  //  M A P   <->   S Q L I T E
  // ----------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'valor': valor,
      'descricao': descricao,
      'forma_pagamento': formaPagamento.index,
      'data_hora': dataHora.millisecondsSinceEpoch,
      'pagamento_fatura': pagamentoFatura ? 1 : 0,
      'pago': pago ? 1 : 0,
      'data_pagamento': dataPagamento?.millisecondsSinceEpoch,
      'categoria': categoria.index,
      'id_cartao': idCartao,
      'id_conta': idConta,
      'grupo_parcelas': grupoParcelas,
      'parcela_numero': parcelaNumero,
      'parcela_total': parcelaTotal,

      // ⭐ NOVO CAMPO: inteiro (0 = receita, 1 = despesa)
      // (se o banco ainda não tiver a coluna, o SQLite ignora na inserção)
      'tipo_movimento': tipoMovimento.index,
    };
  }

  factory Lancamento.fromMap(Map<String, dynamic> map) {
    // forma_pagamento
    final formaIndex = (map['forma_pagamento'] ?? 0) as int;
    final forma =
        (formaIndex >= 0 && formaIndex < FormaPagamento.values.length)
            ? FormaPagamento.values[formaIndex]
            : FormaPagamento.debito;

    // categoria
    final catIndex = (map['categoria'] ?? 0) as int;
    final cat =
        (catIndex >= 0 && catIndex < Categoria.values.length)
            ? Categoria.values[catIndex]
            : Categoria.outros;

    // tipo_movimento (pode não existir nas linhas antigas)
    final tmRaw = map['tipo_movimento'];
    TipoMovimento tipoMov;
    if (tmRaw == null) {
      // ⚠️ DADOS ANTIGOS: assume DESPESA
      tipoMov = TipoMovimento.despesa;
    } else {
      final tmIndex = tmRaw as int;
      if (tmIndex >= 0 && tmIndex < TipoMovimento.values.length) {
        tipoMov = TipoMovimento.values[tmIndex];
      } else {
        tipoMov = TipoMovimento.despesa;
      }
    }

    return Lancamento(
      id: map['id'] as int?,
      valor: (map['valor'] as num).toDouble(),
      descricao: (map['descricao'] ?? '') as String,
      formaPagamento: forma,
      dataHora: DateTime.fromMillisecondsSinceEpoch(map['data_hora'] as int),
      pagamentoFatura: (map['pagamento_fatura'] ?? 0) == 1,
      pago: (map['pago'] ?? 0) == 1,
      dataPagamento:
          map['data_pagamento'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                map['data_pagamento'] as int,
              )
              : null,
      categoria: cat,
      idCartao: map['id_cartao'] as int?,
      idConta: map['id_conta'] as int?,
      grupoParcelas: map['grupo_parcelas'] as String?,
      parcelaNumero: map['parcela_numero'] as int?,
      parcelaTotal: map['parcela_total'] as int?,
      tipoMovimento: tipoMov,
    );
  }
}
