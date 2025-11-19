import 'package:vox_finance/ui/core/enum/categoria.dart';

class CategoriaService {
  /// Regra simples (pode virar IA depois)
  static Categoria fromDescricao(String descricao) {
    final d = descricao.toLowerCase();

    if (d.contains('uber') || d.contains('99')) {
      return Categoria.transporte;
    }
    if (d.contains('mercado') ||
        d.contains('supermercado') ||
        d.contains('atacadão') ||
        d.contains('carrefour')) {
      return Categoria.mercado;
    }
    if (d.contains('ifood') ||
        d.contains('restaurante') ||
        d.contains('lanche') ||
        d.contains('burger') ||
        d.contains('pizza')) {
      return Categoria.alimentacao;
    }
    if (d.contains('farmácia') ||
        d.contains('droga') ||
        d.contains('remédio')) {
      return Categoria.saude;
    }
    if (d.contains('energia') ||
        d.contains('luz') ||
        d.contains('água') ||
        d.contains('internet') ||
        d.contains('telefone') ||
        d.contains('aluguel')) {
      return Categoria.contas;
    }

    return Categoria.outros;
  }
}
