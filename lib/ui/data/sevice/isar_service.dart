import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/models/conta_pagar.dart';

class IsarService {
  IsarService() {
    _db = _openDb();
  }

  late final Future<Isar> _db;

  Future<Isar> get db async => _db;

  // ============================================================
  //  ABERTURA DO BANCO
  // ============================================================

  Future<Isar> _openDb() async {
    if (Isar.instanceNames.isNotEmpty) {
      return Isar.getInstance()!;
    }

    final dir = await getApplicationDocumentsDirectory();

    return Isar.open(
      [LancamentoSchema, ContaPagarSchema],
      directory: dir.path,
      inspector: true,
    );
  }

  // ============================================================
  //  L A N Ç A M E N T O S
  // ============================================================

  /// Lançamentos de um único dia (pagos ou pendentes)
  Future<List<Lancamento>> getLancamentosByDay(DateTime data) async {
    final isar = await db;

    final inicio = DateTime(data.year, data.month, data.day);
    final fim = inicio.add(const Duration(days: 1));

    return isar.lancamentos
        .filter()
        .dataHoraBetween(inicio, fim, includeLower: true, includeUpper: false)
        .sortByDataHoraDesc()
        .findAll();
  }

  /// Lançamentos em período (para gráficos)
  Future<List<Lancamento>> getLancamentosByPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final isar = await db;

    return isar.lancamentos
        .filter()
        .dataHoraBetween(inicio, fim, includeLower: true, includeUpper: false)
        .findAll();
  }

  /// Salvar (inserir/atualizar) lançamento
  Future<void> salvarLancamento(Lancamento lancamento) async {
    final isar = await db;
    await isar.writeTxn(() => isar.lancamentos.put(lancamento));
  }

  /// Excluir lançamento
  Future<void> deleteLancamento(Id id) async {
    final isar = await db;
    await isar.writeTxn(() => isar.lancamentos.delete(id));
  }

  /// Criar lançamentos futuros parcelados
  Future<void> criarLancamentosFuturosParcelados({
    required String descricao,
    required double valorTotal,
    required int quantidadeParcelas,
    required DateTime primeiraData,
    required FormaPagamento formaPagamento,
  }) async {
    final isar = await db;

    final grupo = 'LFUT_${DateTime.now().microsecondsSinceEpoch}';
    final valorParcela = valorTotal / quantidadeParcelas;

    await isar.writeTxn(() async {
      for (var i = 0; i < quantidadeParcelas; i++) {
        final dataParcela = DateTime(
          primeiraData.year,
          primeiraData.month + i,
          primeiraData.day,
        );

        final lanc =
            Lancamento()
              ..valor = valorParcela
              ..descricao = '$descricao (${i + 1}/$quantidadeParcelas)'
              ..formaPagamento = formaPagamento
              ..dataHora = dataParcela
              ..pagamentoFatura = false
              ..pago =
                  false // FUTURO/PENDENTE
              ..dataPagamento = null
              ..categoria = Categoria.contas
              ..grupoParcelas = grupo
              ..parcelaNumero = i + 1
              ..parcelaTotal = quantidadeParcelas;

        await isar.lancamentos.put(lanc);
      }
    });
  }

  /// Marcar lançamento como pago
  Future<void> marcarLancamentoComoPago(Lancamento lanc) async {
    final isar = await db;
    final agora = DateTime.now();

    await isar.writeTxn(() async {
      lanc
        ..pago = true
        ..dataPagamento = agora;
      await isar.lancamentos.put(lanc);
    });
  }

  // ============================================================
  //  C O N T A S  A  P A G A R
  // ============================================================

  Future<List<ContaPagar>> getContasPagar() async {
    final isar = await db;
    return isar.contaPagars.where().sortByDataVencimento().findAll();
  }

  Future<List<ContaPagar>> getContasPagarPendentes() async {
    final isar = await db;
    return isar.contaPagars
        .filter()
        .pagoEqualTo(false)
        .sortByDataVencimento()
        .findAll();
  }

  Future<void> salvarContaPagar(ContaPagar conta) async {
    final isar = await db;
    await isar.writeTxn(() => isar.contaPagars.put(conta));
  }

  Future<void> deleteContaPagar(Id id) async {
    final isar = await db;
    await isar.writeTxn(() => isar.contaPagars.delete(id));
  }

  Future<List<ContaPagar>> getParcelasPorGrupo(String grupoParcelas) async {
    final isar = await db;

    return isar.contaPagars
        .filter()
        .grupoParcelasEqualTo(grupoParcelas)
        .sortByParcelaNumero()
        .findAll();
  }
}
