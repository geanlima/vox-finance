import 'package:flutter/material.dart';

class GrupoResumoDia {
  final String label;
  final String? subtitulo;
  final IconData icon;
  double total;

  GrupoResumoDia({
    required this.label,
    this.subtitulo,
    required this.icon,
    required this.total,
  });
}
