import 'package:sqflite/sqflite.dart';

class VencimentoItem {
  final int origemId;
  final String origemTipo; // 'fixa' | 'variavel'
  final String titulo;
  final DateTime data;
  final int? valorCentavos;
  final String? observacao;
  final bool pago;

  const VencimentoItem({
    required this.origemId,
    required this.origemTipo,
    required this.titulo,
    required this.data,
    required this.valorCentavos,
    required this.observacao,
    required this.pago,
  });

  VencimentoItem copyWith({
    String? titulo,
    DateTime? data,
    int? valorCentavos,
    String? observacao,
    bool? pago,
  }) {
    return VencimentoItem(
      origemId: origemId,
      origemTipo: origemTipo,
      titulo: titulo ?? this.titulo,
      data: data ?? this.data,
      valorCentavos: valorCentavos ?? this.valorCentavos,
      observacao: observacao ?? this.observacao,
      pago: pago ?? this.pago,
    );
  }
}

class VencimentosRepository {
  final Database db;
  const VencimentosRepository(this.db);

  Future<List<VencimentoItem>> listarPorMes(DateTime mes) async {
    final ano = mes.year;
    final mesN = mes.month;

    // 🔸 FIXAS: data = ano_ref/mes_ref/dia_renovacao (ajustada para último dia do mês se passar)
    final fixas = await db.rawQuery(
      '''
      SELECT
        d.id AS origem_id,
        'fixa' AS origem_tipo,
        d.descricao AS titulo,
        d.valor_centavos AS valor_centavos,
        d.status AS status,
        d.data_pagamento_iso AS data_pagamento_iso,
        d.dia_renovacao AS dia_renovacao,
        d.ano_ref AS ano_ref,
        d.mes_ref AS mes_ref
      FROM despesas_fixas d
      WHERE d.ano_ref = ? AND d.mes_ref = ?
        AND d.dia_renovacao IS NOT NULL
      ''',
      [ano, mesN],
    );

    // 🔸 VARIÁVEIS: ajuste o SELECT conforme sua tabela.
    // Exemplo assumindo: despesas_variaveis(data_vencimento_iso, descricao, valor_centavos, status)
    final variaveis = await db.rawQuery(
      '''
      SELECT
        v.id AS origem_id,
        'variavel' AS origem_tipo,
        v.descricao AS titulo,
        v.valor_centavos AS valor_centavos,
        v.status AS status,
        v.data_vencimento_iso AS data_vencimento_iso
      FROM despesas_variaveis v
      WHERE substr(v.data_vencimento_iso, 1, 7) = ?
      ''',
      ['${ano.toString().padLeft(4, '0')}-${mesN.toString().padLeft(2, '0')}'],
    );

    final List<VencimentoItem> itens = [];

    // monta fixas
    for (final m in fixas) {
      final dia = (m['dia_renovacao'] as int?) ?? 1;
      final anoRef = (m['ano_ref'] as int?) ?? ano;
      final mesRef = (m['mes_ref'] as int?) ?? mesN;

      final lastDay = DateTime(anoRef, mesRef + 1, 0).day;
      final diaOk = dia.clamp(1, lastDay);
      final data = DateTime(anoRef, mesRef, diaOk);

      final status = (m['status'] as String?) ?? 'a_pagar';

      itens.add(
        VencimentoItem(
          origemId: m['origem_id'] as int,
          origemTipo: 'fixa',
          titulo: (m['titulo'] as String?) ?? '',
          data: data,
          valorCentavos: m['valor_centavos'] as int?,
          observacao: null,
          pago: status == 'pago',
        ),
      );
    }

    // monta variáveis
    for (final m in variaveis) {
      final iso = (m['data_vencimento_iso'] as String?) ?? '';
      final data = _parseIsoDate(iso);
      if (data == null) continue;

      final status = (m['status'] as String?) ?? 'a_pagar';

      itens.add(
        VencimentoItem(
          origemId: m['origem_id'] as int,
          origemTipo: 'variavel',
          titulo: (m['titulo'] as String?) ?? '',
          data: data,
          valorCentavos: m['valor_centavos'] as int?,
          observacao: null,
          pago: status == 'pago',
        ),
      );
    }

    // ordena: data, pago, título
    itens.sort((a, b) {
      final c1 = a.data.compareTo(b.data);
      if (c1 != 0) return c1;
      final c2 = (a.pago ? 1 : 0).compareTo(b.pago ? 1 : 0);
      if (c2 != 0) return c2;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

    return itens;
  }

  Future<List<VencimentoItem>> listarPorDia(DateTime dia) async {
    final mes = DateTime(dia.year, dia.month, 1);
    final itensMes = await listarPorMes(mes);
    return itensMes.where((x) => _isSameDay(x.data, dia)).toList();
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? _parseIsoDate(String iso) {
    // espera "YYYY-MM-DD"
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
