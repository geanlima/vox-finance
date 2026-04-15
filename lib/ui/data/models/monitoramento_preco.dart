class MonitoramentoPreco {
  final int? id;
  final String produto;
  final double preco; // compat: pode vir 0; UI usa menor_preco quando existir
  final String? loja; // compat legado (oferta única)
  final String? url; // compat legado (oferta única)
  final String? fotoPath;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final int ofertasCount;
  final double? menorPreco;

  const MonitoramentoPreco({
    this.id,
    required this.produto,
    required this.preco,
    this.loja,
    this.url,
    this.fotoPath,
    required this.criadoEm,
    required this.atualizadoEm,
    this.ofertasCount = 0,
    this.menorPreco,
  });

  MonitoramentoPreco copyWith({
    int? id,
    String? produto,
    double? preco,
    String? loja,
    String? url,
    String? fotoPath,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    int? ofertasCount,
    double? menorPreco,
  }) {
    return MonitoramentoPreco(
      id: id ?? this.id,
      produto: produto ?? this.produto,
      preco: preco ?? this.preco,
      loja: loja ?? this.loja,
      url: url ?? this.url,
      fotoPath: fotoPath ?? this.fotoPath,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      ofertasCount: ofertasCount ?? this.ofertasCount,
      menorPreco: menorPreco ?? this.menorPreco,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'produto': produto,
      'preco': preco,
      'loja': loja,
      'url': url,
      'foto_path': fotoPath,
      'criado_em': criadoEm.millisecondsSinceEpoch,
      'atualizado_em': atualizadoEm.millisecondsSinceEpoch,
    };
  }

  factory MonitoramentoPreco.fromMap(Map<String, dynamic> m) {
    return MonitoramentoPreco(
      id: (m['id'] as num?)?.toInt(),
      produto: (m['produto'] ?? '') as String,
      preco: (m['preco'] as num).toDouble(),
      loja: m['loja'] as String?,
      url: m['url'] as String?,
      fotoPath: m['foto_path'] as String?,
      criadoEm: DateTime.fromMillisecondsSinceEpoch(
        (m['criado_em'] as num).toInt(),
      ),
      atualizadoEm: DateTime.fromMillisecondsSinceEpoch(
        ((m['atualizado_em_calc'] ?? m['atualizado_em']) as num).toInt(),
      ),
      ofertasCount: ((m['ofertas_count'] ?? 0) as num).toInt(),
      menorPreco: (m['menor_preco'] as num?)?.toDouble(),
    );
  }
}

