// ignore_for_file: public_member_api_docs

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.trim().replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll(',', '.');
    return double.tryParse(s);
  }
  return null;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    if (v > 2000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v > 1000000000) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  if (v is String) {
    final t = DateTime.tryParse(v);
    if (t != null) return t;
  }
  return null;
}

DateTime? _parseDateCompetencia(dynamic v, {required int ano, required int mes}) {
  final base = _parseDate(v);
  if (base != null) return base;
  if (v is! String) return null;

  final s = v.trim();
  if (s.isEmpty) return null;

  // Ex.: "10/02" (dia/mês) ou "10/02/2026"
  final m1 = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$').firstMatch(s);
  if (m1 != null) {
    final dia = int.tryParse(m1.group(1)!) ?? 1;
    final m = int.tryParse(m1.group(2)!) ?? mes;
    final yStr = m1.group(3);
    int y;
    if (yStr != null && yStr.isNotEmpty) {
      y = int.tryParse(yStr) ?? ano;
      // Ajuste para ano com 2 dígitos (ex.: 26 -> 2026)
      if (yStr.length == 2) y += 2000;
    } else {
      // Se API manda só dia/mês, assume ano da competência;
      // se o mês for "maior" que o mês da fatura, provavelmente é do ano anterior.
      y = (m > mes) ? (ano - 1) : ano;
    }
    return DateTime(y, m, dia, 12);
  }

  // Ex.: "10-02" (dia-mês) ou "10-02-2026"
  final m2 = RegExp(r'^(\d{1,2})-(\d{1,2})(?:-(\d{2,4}))?$').firstMatch(s);
  if (m2 != null) {
    final dia = int.tryParse(m2.group(1)!) ?? 1;
    final m = int.tryParse(m2.group(2)!) ?? mes;
    final yStr = m2.group(3);
    int y;
    if (yStr != null && yStr.isNotEmpty) {
      y = int.tryParse(yStr) ?? ano;
      if (yStr.length == 2) y += 2000;
    } else {
      y = (m > mes) ? (ano - 1) : ano;
    }
    return DateTime(y, m, dia, 12);
  }

  return null;
}

({int ano, int mes})? _parseCompetenciaMmYyyy(dynamic v) {
  if (v is! String) return null;
  final s = v.trim();
  final m = RegExp(r'^(\d{1,2})\s*/\s*(\d{4})$').firstMatch(s);
  if (m == null) return null;
  final mes = int.tryParse(m.group(1)!) ?? 0;
  final ano = int.tryParse(m.group(2)!) ?? 0;
  if (mes < 1 || mes > 12 || ano < 1900) return null;
  return (ano: ano, mes: mes);
}

/// Linha de lançamento vinda da API (item de fatura).
class LancamentoFaturaApiDto {
  LancamentoFaturaApiDto({
    this.id,
    required this.descricao,
    required this.valor,
    this.dataHora,
    this.categoria,
  });

  final String? id;
  final String descricao;
  final double valor;
  final DateTime? dataHora;
  final String? categoria;

  factory LancamentoFaturaApiDto.fromJson(
    Map<String, dynamic> m, {
    int? anoCompetencia,
    int? mesCompetencia,
  }) {
    final desc =
        '${m['descricao'] ?? m['nome'] ?? m['titulo'] ?? m['historico'] ?? m['memo'] ?? ''}'
            .trim();
    final valor =
        _parseDouble(
          m['valor'] ?? m['valor_total'] ?? m['amount'] ?? m['value'],
        ) ??
        0.0;
    final rawData =
        m['data'] ?? m['data_hora'] ?? m['dataHora'] ?? m['date'] ?? m['created_at'];
    return LancamentoFaturaApiDto(
      id: m['id']?.toString(),
      descricao: desc.isEmpty ? '(sem descrição)' : desc,
      valor: valor,
      dataHora:
          (anoCompetencia != null && mesCompetencia != null)
              ? _parseDateCompetencia(
                rawData,
                ano: anoCompetencia,
                mes: mesCompetencia,
              )
              : _parseDate(rawData),
      categoria:
          (m['categoria'] ?? m['category'] ?? m['tipo'])?.toString(),
    );
  }
}

/// Fatura retornada pela API (um ou mais por cartão/mês).
class FaturaApiDto {
  FaturaApiDto({
    this.id,
    this.descricao,
    required this.valorTotal,
    this.dataVencimento,
    this.dataFechamento,
    this.pago,
    required this.lancamentos,
  });

  final String? id;
  final String? descricao;
  final double valorTotal;
  final DateTime? dataVencimento;
  final DateTime? dataFechamento;
  final bool? pago;
  final List<LancamentoFaturaApiDto> lancamentos;

  double get somaLancamentos =>
      lancamentos.fold<double>(0, (a, l) => a + l.valor);

  factory FaturaApiDto.fromJson(Map<String, dynamic> m) {
    final comp = _parseCompetenciaMmYyyy(m['competencia']);
    final rawLanc =
        m['lancamentos'] ??
        m['itens'] ??
        m['movimentos'] ??
        m['transacoes'] ??
        m['lancamento_list'];
    final lista = <LancamentoFaturaApiDto>[];
    if (rawLanc is List) {
      for (final e in rawLanc) {
        if (e is! Map) continue;
        lista.add(
          LancamentoFaturaApiDto.fromJson(
            Map<String, dynamic>.from(e),
            anoCompetencia: comp?.ano,
            mesCompetencia: comp?.mes,
          ),
        );
      }
    }

    var valor = _parseDouble(
      m['total_fatura'] ??
          m['valor_total'] ??
          m['valorTotal'] ??
          m['total'] ??
          m['valor'],
    );
    if ((valor == null || valor == 0) && lista.isNotEmpty) {
      valor = lista.fold<double>(0, (a, l) => a + l.valor);
    }
    valor ??= 0.0;

    final pg = m['pago'];
    bool? pago;
    if (pg is bool) {
      pago = pg;
    } else if (pg is num) {
      pago = pg != 0;
    } else if (pg is String) {
      final s = pg.toLowerCase();
      if (s == 'true' || s == '1' || s == 'pago') pago = true;
      if (s == 'false' || s == '0' || s == 'aberto') pago = false;
    }

    var desc =
        '${m['descricao'] ?? m['nome'] ?? m['titulo'] ?? ''}'.trim();
    if (desc.isEmpty) {
      final snap =
          '${m['cartao_nome_snapshot'] ?? m['cartaoNomeSnapshot'] ?? ''}'
              .trim();
      final banco = '${m['banco'] ?? ''}'.trim();
      final compStr = '${m['competencia'] ?? ''}'.trim();
      if (snap.isNotEmpty) {
        desc = banco.isNotEmpty ? '$banco · $snap' : snap;
      } else if (banco.isNotEmpty && compStr.isNotEmpty) {
        desc = '$banco · $compStr';
      } else if (compStr.isNotEmpty) {
        desc = compStr;
      } else if (banco.isNotEmpty) {
        desc = banco;
      }
    }

    return FaturaApiDto(
      id: m['id']?.toString(),
      descricao: desc.isEmpty ? null : desc,
      valorTotal: valor,
      dataVencimento: _parseDate(
        m['data_vencimento'] ??
            m['dataVencimento'] ??
            m['vencimento'] ??
            m['due_date'],
      ),
      dataFechamento: _parseDate(
        m['data_fechamento'] ?? m['dataFechamento'] ?? m['fechamento'],
      ),
      pago: pago,
      lancamentos: lista,
    );
  }
}
