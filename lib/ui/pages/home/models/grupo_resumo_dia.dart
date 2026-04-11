import 'package:flutter/material.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';

class GrupoResumoDia {
  final String label;
  final String? subtitulo;
  final IconData icon;
  double total;

  /// Lançamentos que compõem [total] (para drill-down).
  final List<Lancamento> lancamentos;

  GrupoResumoDia({
    required this.label,
    this.subtitulo,
    required this.icon,
    required this.total,
    List<Lancamento>? lancamentos,
  }) : lancamentos = lancamentos ?? [];
}
