// lib/ui/data/models/lancamento.dart

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/enum/categoria.dart';

/// Tipo do movimento financeiro:
/// - receita  -> entra dinheiro
/// - despesa  -> sai dinheiro
enum TipoMovimento { receita, despesa, ambos }

extension TipoMovimentoExt on TipoMovimento {
  String get label {
    switch (this) {
      case TipoMovimento.receita:
        return 'Receita';
      case TipoMovimento.despesa:
        return 'Despesa';
      case TipoMovimento.ambos:
        return 'Ambos';
    }
  }
}

/// ⭐ NOVO: tipo de despesa (para agrupar no menu em Fixas/Variáveis)
/// Obs: só faz sentido quando tipoMovimento == despesa
enum TipoDespesa { fixa, variavel }

extension TipoDespesaExt on TipoDespesa {
  String get label {
    switch (this) {
      case TipoDespesa.fixa:
        return 'Fixa';
      case TipoDespesa.variavel:
        return 'Variável';
    }
  }
}

class Lancamento {
  /// Sentinela para [copyWith] permitir `idCartao: null` / `idConta: null` explícitos.
  static const Object _copyWithUnset = Object();

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

  /// Categoria "padrão" (enum)
  Categoria categoria;

  int? idCartao;
  int? idConta;

  /// Grupo para parcelados (mesmo grupo = mesma compra)
  String? grupoParcelas;
  int? parcelaNumero;
  int? parcelaTotal;

  /// ⭐ se é receita ou despesa
  TipoMovimento tipoMovimento;

  /// ⭐ referência à categoria_personalizada (se houver)
  int? idCategoriaPersonalizada;

  /// ⭐ referência à subcategoria_personalizada (se houver)
  int? idSubcategoriaPersonalizada;

  /// ⭐ NOVO: fixa/variável
  /// por padrão, tudo que já existe vira "variável"
  TipoDespesa tipoDespesa;

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

    /// se não tiver categoria personalizada, fica null
    this.idCategoriaPersonalizada,

    /// se não tiver subcategoria personalizada, fica null
    this.idSubcategoriaPersonalizada,

    /// ⭐ NOVO: por padrão "variável" (melhor fallback para bases antigas)
    this.tipoDespesa = TipoDespesa.variavel,
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
    Object? idCartao = _copyWithUnset,
    Object? idConta = _copyWithUnset,
    String? grupoParcelas,
    int? parcelaNumero,
    int? parcelaTotal,
    TipoMovimento? tipoMovimento,
    int? idCategoriaPersonalizada,
    int? idSubcategoriaPersonalizada,
    TipoDespesa? tipoDespesa, // ⭐ NOVO
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
      idCartao:
          identical(idCartao, _copyWithUnset)
              ? this.idCartao
              : idCartao as int?,
      idConta:
          identical(idConta, _copyWithUnset)
              ? this.idConta
              : idConta as int?,
      grupoParcelas: grupoParcelas ?? this.grupoParcelas,
      parcelaNumero: parcelaNumero ?? this.parcelaNumero,
      parcelaTotal: parcelaTotal ?? this.parcelaTotal,
      tipoMovimento: tipoMovimento ?? this.tipoMovimento,
      idCategoriaPersonalizada:
          idCategoriaPersonalizada ?? this.idCategoriaPersonalizada,
      idSubcategoriaPersonalizada:
          idSubcategoriaPersonalizada ?? this.idSubcategoriaPersonalizada,
      tipoDespesa: tipoDespesa ?? this.tipoDespesa, // ⭐ NOVO
    );
  }

  // ----------------------------------------------------------
  //  U I  —  grupo / parcelas (despesas fixas usam prefixo FIXA_)
  // ----------------------------------------------------------

  /// Contas geradas por [DespesaFixaRepository] usam `grupo_parcelas` = `FIXA_{id}_YYYYMM`
  /// com `parcela_total` = 1; não devem aparecer como "Parcela 1/1".
  bool get ehGrupoDespesaFixa =>
      grupoParcelas != null && grupoParcelas!.startsWith('FIXA_');

  /// Exibir linha "Parcela X/Y" na lista principal (só compras com mais de uma parcela).
  bool get exibirRotuloParcelaNaLista =>
      !ehGrupoDespesaFixa &&
      parcelaTotal != null &&
      parcelaTotal! > 1;

  /// Linha extra em detalhes (bottom sheet da fatura, etc.).
  /// Não mostra "Parcela 1/1"; para fixas mostra só [Despesa fixa].
  String? get linhaDetalheGrupoParcela {
    final g = grupoParcelas;
    if (g == null || g.isEmpty) return null;
    if (ehGrupoDespesaFixa) return 'Despesa fixa';
    final tot = parcelaTotal ?? 1;
    final num = parcelaNumero ?? 1;
    if (tot > 1) return 'Grupo: $g · Parcela $num/$tot';
    return 'Grupo: $g';
  }

  /// Texto curto para listas (ex.: detalhe de fatura no cartão): sem "1/1".
  String? get linhaResumoParcelaCurta {
    final g = grupoParcelas;
    if (g == null || g.isEmpty) return null;
    if (ehGrupoDespesaFixa) return 'Despesa fixa';
    final tot = parcelaTotal ?? 1;
    final num = parcelaNumero ?? 1;
    if (tot > 1) return 'Parcela $num/$tot';
    return null;
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

      // ⭐ inteiro (0 = receita, 1 = despesa, 2 = ambos)
      'tipo_movimento': tipoMovimento.index,

      // ⭐ FK para categorias_personalizadas
      'id_categoria_personalizada': idCategoriaPersonalizada,

      // ⭐ FK para subcategorias_personalizadas
      'id_subcategoria_personalizada': idSubcategoriaPersonalizada,

      // ⭐ NOVO: 0 = fixa, 1 = variavel
      'tipo_despesa': tipoDespesa.index,
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

    // ⭐ NOVO: tipo_despesa (pode não existir em bases antigas)
    final tdRaw = map['tipo_despesa'];
    TipoDespesa tipoDesp;
    if (tdRaw == null) {
      // ⚠️ DADOS ANTIGOS: assume VARIÁVEL
      tipoDesp = TipoDespesa.variavel;
    } else {
      final tdIndex = tdRaw as int;
      if (tdIndex >= 0 && tdIndex < TipoDespesa.values.length) {
        tipoDesp = TipoDespesa.values[tdIndex];
      } else {
        tipoDesp = TipoDespesa.variavel;
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

      // ⭐ lê do banco (pode ser null)
      idCategoriaPersonalizada: map['id_categoria_personalizada'] as int?,

      // ⭐ lê do banco (pode ser null)
      idSubcategoriaPersonalizada:
          map['id_subcategoria_personalizada'] as int?,

      // ⭐ NOVO
      tipoDespesa: tipoDesp,
    );
  }
}
