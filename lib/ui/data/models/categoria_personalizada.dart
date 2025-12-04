// lib/ui/data/models/categoria_personalizada.dart
import 'package:flutter/material.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart'; // onde está o enum TipoMovimento

class CategoriaPersonalizada {
  final int? id;
  final String nome;
  final TipoMovimento tipoMovimento;

  /// Valor da cor em HEX (ex: "#FF2196F3") ou null
  final String? corHex;

  CategoriaPersonalizada({
    this.id,
    required this.nome,
    required this.tipoMovimento,
    this.corHex,
  });

  /// Converte corHex -> Color (ou null se não tiver)
  Color? get cor {
    if (corHex == null || corHex!.isEmpty) return null;

    try {
      var value = corHex!;
      // remove '#'
      if (value.startsWith('#')) {
        value = value.substring(1);
      }
      // se vier só RGB, prefixa alpha
      if (value.length == 6) {
        value = 'FF$value';
      }
      final intColor = int.parse(value, radix: 16);
      return Color(intColor);
    } catch (_) {
      return null;
    }
  }

  /// Constrói a partir do Map do SQLite
  factory CategoriaPersonalizada.fromMap(Map<String, dynamic> map) {
    // tipo_movimento pode vir null ou fora do range
    final tmRaw = map['tipo_movimento'];
    int tmIndex = 1; // padrão = despesa
    if (tmRaw is int) {
      tmIndex = tmRaw;
    }

    if (tmIndex < 0 || tmIndex >= TipoMovimento.values.length) {
      tmIndex = 1;
    }

    return CategoriaPersonalizada(
      id: map['id'] as int?,                          // ok ser null em alguns casos
      nome: (map['nome'] ?? '') as String,           // garante String
      tipoMovimento: TipoMovimento.values[tmIndex],
      corHex: map['cor'] as String?,                 // 👈 AGORA ACEITA NULL
    );
  }

  /// Converte para Map pra salvar no SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo_movimento': tipoMovimento.index,
      'cor': corHex,
    };
  }

  CategoriaPersonalizada copyWith({
    int? id,
    String? nome,
    TipoMovimento? tipoMovimento,
    String? corHex,
  }) {
    return CategoriaPersonalizada(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipoMovimento: tipoMovimento ?? this.tipoMovimento,
      corHex: corHex ?? this.corHex,
    );
  }
}
