/// Cartão retornado pela API (para de-para com o cadastro local).
class CartaoApiDto {
  CartaoApiDto({
    required this.id,
    required this.descricao,
    this.bandeira,
    this.ultimos4,
  });

  final String id;
  final String descricao;
  final String? bandeira;
  final String? ultimos4;

  String get label {
    final u = ultimos4 != null && ultimos4!.isNotEmpty ? ' • **** $ultimos4' : '';
    return '$descricao$u';
  }

  factory CartaoApiDto.fromJson(Map<String, dynamic> m) {
    final rawId = m['id'] ?? m['cartao_id'] ?? m['id_cartao'];
    final id = rawId?.toString() ?? '';
    final desc =
        '${m['descricao'] ?? m['nome'] ?? m['titulo'] ?? ''}'.trim();
    return CartaoApiDto(
      id: id,
      descricao: desc,
      bandeira: m['bandeira'] as String?,
      ultimos4: (m['ultimos4'] ?? m['ultimos_4'] ?? m['ultimos4Digitos'])?.toString(),
    );
  }
}
