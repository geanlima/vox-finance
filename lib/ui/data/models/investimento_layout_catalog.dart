/// Layouts disponíveis ao cadastrar uma carteira de investimento.
/// Novos layouts: incluir aqui e implementar a tela correspondente.
class InvestimentoLayoutCatalog {
  InvestimentoLayoutCatalog._();

  static const List<InvestimentoLayoutDef> todos = [
    InvestimentoLayoutDef(
      id: 'bluminers',
      titulo: 'Bluminers',
      descricao:
          'Dois saldos (investido e disponível), rendimento diário por %, importação de taxas.',
    ),
  ];

  static InvestimentoLayoutDef? porId(String id) {
    for (final e in todos) {
      if (e.id == id) return e;
    }
    return null;
  }

  static String tituloOuId(String id) => porId(id)?.titulo ?? id;

  static String get padraoId => todos.first.id;

  static bool existe(String id) => porId(id) != null;
}

class InvestimentoLayoutDef {
  final String id;
  final String titulo;
  final String descricao;

  const InvestimentoLayoutDef({
    required this.id,
    required this.titulo,
    required this.descricao,
  });
}
