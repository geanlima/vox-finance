enum Categoria {
  mercado,
  alimentacao,
  farmacia,
  transporte,
  moradia,
  lazer,
  renda,
  outros,
  saude,
  contas,
  educacao,
  restaurantes,
}

class CategoriaService {
  /// Converte enum → nome de exibição
  static String toName(Categoria cat) {
    switch (cat) {
      case Categoria.mercado:
        return "Mercado";
      case Categoria.transporte:
        return "Transporte";
      case Categoria.lazer:
        return "Lazer";
      case Categoria.contas:
        return "Contas";
      case Categoria.saude:
        return "Saúde";
      case Categoria.educacao:
        return "Educação";
      case Categoria.restaurantes:
        return "Restaurantes";
      case Categoria.outros:
      default:
        return "Outros";
    }
  }

  /// Converte descrição → categoria automaticamente
  static Categoria fromDescricao(String descricao) {
    final desc = descricao.toLowerCase().trim();

    // Mercado / compras
    if (desc.contains("merc") ||
        desc.contains("super") ||
        desc.contains("compra") ||
        desc.contains("sacolão") ||
        desc.contains("horti")) {
      return Categoria.mercado;
    }

    // Transporte
    if (desc.contains("uber") ||
        desc.contains("99") ||
        desc.contains("taxi") ||
        desc.contains("combust") ||
        desc.contains("posto") ||
        desc.contains("gas")) {
      return Categoria.transporte;
    }

    // Restaurantes
    if (desc.contains("rest") ||
        desc.contains("lanche") ||
        desc.contains("burg") ||
        desc.contains("pizza") ||
        desc.contains("bar") ||
        desc.contains("caf") ||
        desc.contains("food")) {
      return Categoria.restaurantes;
    }

    // Lazer
    if (desc.contains("cinema") ||
        desc.contains("parque") ||
        desc.contains("show") ||
        desc.contains("lazer") ||
        desc.contains("netflix") ||
        desc.contains("spotify")) {
      return Categoria.lazer;
    }

    // Contas (fixas)
    if (desc.contains("luz") ||
        desc.contains("energia") ||
        desc.contains("água") ||
        desc.contains("claro") ||
        desc.contains("vivo") ||
        desc.contains("tim") ||
        desc.contains("fone") ||
        desc.contains("internet") ||
        desc.contains("boleto") ||
        desc.contains("aluguel")) {
      return Categoria.contas;
    }

    // Saúde
    if (desc.contains("farm") ||
        desc.contains("rem") ||
        desc.contains("clinic") ||
        desc.contains("dent") ||
        desc.contains("saúde") ||
        desc.contains("hospital")) {
      return Categoria.saude;
    }

    // Educação
    if (desc.contains("curso") ||
        desc.contains("facul") ||
        desc.contains("escola") ||
        desc.contains("livro") ||
        desc.contains("apostila")) {
      return Categoria.educacao;
    }

    // Se não identificar → OUTROS
    return Categoria.outros;
  }
}
