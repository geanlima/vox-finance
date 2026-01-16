import 'package:vox_finance/v2/infrastructure/repositories/balanco_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/caca_precos_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/categorias_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/cofrinho_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/desafio_financeiro_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/desejos_compras_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/despesas_variaveis_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/dividas_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/formas_pagamento_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/ganhos_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/mural_sonhos_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/parcelamentos_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/pessoas_devedoras_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/vencimentos_repository.dart';
import 'package:vox_finance/v2/infrastructure/repositories/despesas_fixas_repository.dart';

import '../../infrastructure/db/db_service_v2.dart';
import '../../infrastructure/repositories/notas_rapidas_repository.dart';

class InjectorV2 {
  static late final DbServiceV2 db;

  static late final NotasRapidasRepository notasRepo;
  static late final VencimentosRepository vencimentosRepo;
  static late final BalancoRepository balancoRepo;
  static late final CategoriasRepository categoriasRepo;

  static late final GanhosRepository ganhosRepo;
  static late final DespesasFixasRepository despesasFixasRepo;
  static late final DespesasVariaveisRepository despesasVariaveisRepo;
  static late final FormasPagamentoRepository formasPagamentoRepo;
  static late final ParcelamentosRepository parcelamentosRepo;
  static late final DividasRepository dividasRepo;
  static late final PessoasDevedorasRepository pessoasDevedorasRepo;
  static late final CofrinhoRepository cofrinhoRepo;
  static late final DesejosComprasRepository desejosComprasRepo;
  static late final CacaPrecosRepository cacaPrecosRepo;
  static late final MuralSonhosRepository muralSonhosRepo;
  static late final DesafioFinanceiroRepository desafioFinanceiroRepo;

  static Future<void> init() async {
    db = DbServiceV2();
    await db.openAndMigrate();

    notasRepo = NotasRapidasRepository(db.db);
    vencimentosRepo = VencimentosRepository(db.db);
    balancoRepo = BalancoRepository(db.db);
    categoriasRepo = CategoriasRepository(db.db);

    ganhosRepo = GanhosRepository(db.db);
    despesasFixasRepo = DespesasFixasRepository(db.db);
    despesasVariaveisRepo = DespesasVariaveisRepository(db.db);
    formasPagamentoRepo = FormasPagamentoRepository(db.db);

    parcelamentosRepo = ParcelamentosRepository(db.db);
    dividasRepo = DividasRepository(db.db);
    pessoasDevedorasRepo = PessoasDevedorasRepository(db.db);
    cofrinhoRepo = CofrinhoRepository(db.db);
    desejosComprasRepo = DesejosComprasRepository(db.db);
    cacaPrecosRepo = CacaPrecosRepository(db.db);
    muralSonhosRepo = MuralSonhosRepository(db.db);
    desafioFinanceiroRepo = DesafioFinanceiroRepository(db.db);

    await categoriasRepo.seedPadraoSeVazio();
  }
}
