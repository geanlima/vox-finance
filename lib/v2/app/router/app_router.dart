import 'package:flutter/material.dart';
import 'package:vox_finance/v2/presentation/pages/calendario_vencimentos/calendario_vencimentos_page.dart';
import 'package:vox_finance/v2/presentation/pages/categorias/categorias_page.dart';

import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/notas_rapidas/notas_rapidas_page.dart';
import '../../presentation/pages/balanco/balanco_page.dart';
import '../../presentation/pages/gastos_por_categoria/gastos_por_categoria_page.dart';
import '../../presentation/pages/meus_ganhos/meus_ganhos_page.dart';
import '../../presentation/pages/despesas_fixas/despesas_fixas_page.dart';
import '../../presentation/pages/despesas_variaveis/despesas_variaveis_page.dart';
import '../../presentation/pages/formas_pagamento/formas_pagamento_page.dart';
import '../../presentation/pages/parcelamento/parcelamento_page.dart';
import '../../presentation/pages/dividas/dividas_page.dart';
import '../../presentation/pages/pessoas_me_devem/pessoas_me_devem_page.dart';
import '../../presentation/pages/cofrinho/cofrinho_page.dart';
import '../../presentation/pages/desejo_compras/desejo_compras_page.dart';
import '../../presentation/pages/caca_precos/caca_precos_page.dart';
import '../../presentation/pages/mural_sonhos/mural_sonhos_page.dart';
import '../../presentation/pages/desafio_financeiro/desafio_financeiro_page.dart';
import '../../presentation/pages/investimentos/investimentos_page.dart';

class AppRouterV2 {
  static const home = '/';

  static const notasRapidas = '/notas';
  static const balanco = '/balanco';
  static const gastosCategorias = '/gastos-categorias';

  static const meusGanhos = '/ganhos';
  static const despesasFixas = '/despesas-fixas';
  static const despesasVariaveis = '/despesas-variaveis';

  static const formasPagamento = '/formas-pagamento';
  static const parcelamento = '/parcelamento';
  static const dividas = '/dividas';
  static const pessoasMeDevem = '/pessoas-me-devem';

  static const cofrinho = '/cofrinho';
  static const desejoCompras = '/desejo-compras';
  static const cacaPrecos = '/caca-precos';
  static const muralSonhos = '/mural-sonhos';
  static const desafioFinanceiro = '/desafio-financeiro';

  static const investimentos = '/investimentos';

  static const calendarioVencimentos = '/calendario-vencimentos';
  static const categorias = '/categorias';

  static final routes = <String, WidgetBuilder>{
    home: (_) => const HomePageV2(),

    notasRapidas: (_) => const NotasRapidasPage(),
    balanco: (_) => const BalancoPage(),
    gastosCategorias: (_) => const GastosPorCategoriaPage(),
    calendarioVencimentos: (_) => const CalendarioVencimentosPage(),

    meusGanhos: (_) => const MeusGanhosPage(),
    despesasFixas: (_) => const DespesasFixasPage(),
    despesasVariaveis: (_) => const DespesasVariaveisPage(),

    formasPagamento: (_) => const FormasPagamentoPage(),
    parcelamento: (_) => const ParcelamentosPage(),
    dividas: (_) => const DividasPage(),
    pessoasMeDevem: (_) => const PessoasMeDevemPage(),
    categorias: (_) => const CategoriasPage(),

    cofrinho: (_) => const CofrinhoPage(),
    desejoCompras: (_) => const DesejoComprasPage(),
    cacaPrecos: (_) => const CacaPrecosPage(),
    muralSonhos: (_) => const MuralSonhosPage(),
    desafioFinanceiro: (_) => const DesafioFinanceiroPage(),

    investimentos: (_) => const InvestimentosPage(),
  };
}
