import 'package:flutter/material.dart';

enum Categoria {
  alimentacao,
  educacao,
  familia,
  financasPessoais,
  impostosETaxas,
  lazerEEntretenimento,
  moradia,
  outros,
  presentesEDoacoes,
  saude,
  seguros,
  tecnologia,
  transporte,
  vestuario,
}

class CategoriaService {
  /// Converte enum → nome de exibição
  static String toName(Categoria cat) {
    switch (cat) {
      case Categoria.alimentacao:
        return "Alimentação";
      case Categoria.educacao:
        return "Educação";
      case Categoria.familia:
        return "Família";
      case Categoria.financasPessoais:
        return "Finanças Pessoais";
      case Categoria.impostosETaxas:
        return "Impostos e Taxas";
      case Categoria.lazerEEntretenimento:
        return "Lazer e Entretenimento";
      case Categoria.moradia:
        return "Moradia";
      case Categoria.outros:
        return "Outros";
      case Categoria.presentesEDoacoes:
        return "Presentes e Doações";
      case Categoria.saude:
        return "Saúde";
      case Categoria.seguros:
        return "Seguros";
      case Categoria.tecnologia:
        return "Tecnologia";
      case Categoria.transporte:
        return "Transporte";
      case Categoria.vestuario:
        return "Vestuário";
    }
  }

  /// Converte descrição livre → categoria automaticamente
  static Categoria fromDescricao(String descricao) {
    final desc = descricao.toLowerCase().trim();

    // Mercado / compras
    if (desc.contains("merc") ||
        desc.contains("super") ||
        desc.contains("compra") ||
        desc.contains("sacolão") ||
        desc.contains("horti")) {
      return Categoria.alimentacao;
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
      return Categoria.alimentacao;
    }

    // Lazer
    if (desc.contains("cinema") ||
        desc.contains("parque") ||
        desc.contains("show") ||
        desc.contains("lazer") ||
        desc.contains("netflix") ||
        desc.contains("spotify")) {
      return Categoria.lazerEEntretenimento;
    }

    // Contas (fixas)
    if (desc.contains("luz") ||
        desc.contains("energia") ||
        desc.contains("água") ||
        desc.contains("agua") ||
        desc.contains("claro") ||
        desc.contains("vivo") ||
        desc.contains("tim") ||
        desc.contains("fone") ||
        desc.contains("internet") ||
        desc.contains("boleto") ||
        desc.contains("aluguel")) {
      return Categoria.impostosETaxas;
    }

    // Saúde
    if (desc.contains("farm") ||
        desc.contains("rem") ||
        desc.contains("clinic") ||
        desc.contains("dent") ||
        desc.contains("saúde") ||
        desc.contains("saude") ||
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

  /// Ícone por categoria
  static IconData icon(Categoria cat) {
    switch (cat) {
      case Categoria.alimentacao:
        return Icons.restaurant;
      case Categoria.educacao:
        return Icons.school;
      case Categoria.familia:
        return Icons.family_restroom;
      case Categoria.financasPessoais:
        return Icons.account_balance_wallet;
      case Categoria.impostosETaxas:
        return Icons.receipt_long;
      case Categoria.lazerEEntretenimento:
        return Icons.movie;
      case Categoria.moradia:
        return Icons.home;
      case Categoria.outros:
        return Icons.more_horiz;
      case Categoria.presentesEDoacoes:
        return Icons.card_giftcard;
      case Categoria.saude:
        return Icons.medical_services;
      case Categoria.seguros:
        return Icons.verified_user;
      case Categoria.tecnologia:
        return Icons.devices;
      case Categoria.transporte:
        return Icons.directions_car;
      case Categoria.vestuario:
        return Icons.shopping_bag;
    }
  }

  /// Cor por categoria
  static Color color(Categoria cat) {
    switch (cat) {
      case Categoria.alimentacao:
        return Colors.orange;
      case Categoria.educacao:
        return Colors.blue;
      case Categoria.familia:
        return Colors.purple;
      case Categoria.financasPessoais:
        return Colors.teal;
      case Categoria.impostosETaxas:
        return Colors.brown;
      case Categoria.lazerEEntretenimento:
        return Colors.indigo;
      case Categoria.moradia:
        return Colors.green;
      case Categoria.outros:
        return Colors.grey;
      case Categoria.presentesEDoacoes:
        return Colors.redAccent;
      case Categoria.saude:
        return Colors.red;
      case Categoria.seguros:
        return Colors.cyan;
      case Categoria.tecnologia:
        return Colors.deepPurple;
      case Categoria.transporte:
        return Colors.blueGrey;
      case Categoria.vestuario:
        return Colors.pink;
    }
  }

  // ==========================================================
  //  MAPEAMENTO ENUM  <->  ID DA TABELA
  // ==========================================================

  /// Converte enum -> ID da tabela de categorias
  ///
  /// ⚠️ IMPORTANTE:
  /// Garanta que esses IDs sejam os mesmos usados ao popular a tabela.
  static int idFromEnum(Categoria cat) {
    switch (cat) {
      case Categoria.alimentacao:
        return 1;
      case Categoria.educacao:
        return 2;
      case Categoria.familia:
        return 3;
      case Categoria.financasPessoais:
        return 4;
      case Categoria.impostosETaxas:
        return 5;
      case Categoria.lazerEEntretenimento:
        return 6;
      case Categoria.moradia:
        return 7;
      case Categoria.outros:
        return 8;
      case Categoria.presentesEDoacoes:
        return 9;
      case Categoria.saude:
        return 10;
      case Categoria.seguros:
        return 11;
      case Categoria.tecnologia:
        return 12;
      case Categoria.transporte:
        return 13;
      case Categoria.vestuario:
        return 14;
    }
  }

  /// Converte ID da tabela -> enum Categoria
  ///
  /// Útil se em algum momento você quiser montar enums
  /// a partir do ID gravado no banco.
  static Categoria fromId(int id) {
    switch (id) {
      case 1:
        return Categoria.alimentacao;
      case 2:
        return Categoria.educacao;
      case 3:
        return Categoria.familia;
      case 4:
        return Categoria.financasPessoais;
      case 5:
        return Categoria.impostosETaxas;
      case 6:
        return Categoria.lazerEEntretenimento;
      case 7:
        return Categoria.moradia;
      case 8:
        return Categoria.outros;
      case 9:
        return Categoria.presentesEDoacoes;
      case 10:
        return Categoria.saude;
      case 11:
        return Categoria.seguros;
      case 12:
        return Categoria.tecnologia;
      case 13:
        return Categoria.transporte;
      case 14:
        return Categoria.vestuario;
      default:
        return Categoria.outros;
    }
  }
}
