import 'dart:math' as math;

import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_config_repository.dart';
import 'package:vox_finance/ui/data/modules/investimentos/cdi/investimento_cdi_rendimentos_repository.dart';
import 'package:vox_finance/ui/data/modules/lancamentos/lancamento_repository.dart';

class InvestimentoCdiService {
  final InvestimentoCdiConfigRepository _cfgRepo = InvestimentoCdiConfigRepository();
  final InvestimentoCdiRendimentosRepository _rendRepo =
      InvestimentoCdiRendimentosRepository();
  final LancamentoRepository _lancRepo = LancamentoRepository();

  bool _ehFimDeSemana(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  int _diasNoMes(DateTime ref, {required bool incluirFimDeSemana}) {
    final primeiro = DateTime(ref.year, ref.month, 1);
    final ultimo = DateTime(ref.year, ref.month + 1, 0);
    if (incluirFimDeSemana) return ultimo.day;

    int uteis = 0;
    for (int day = 1; day <= ultimo.day; day++) {
      final d = DateTime(primeiro.year, primeiro.month, day);
      if (_ehFimDeSemana(d)) continue;
      uteis++;
    }
    return uteis <= 0 ? ultimo.day : uteis;
  }

  /// Processa rendimentos diários até hoje (inclusive), gerando lançamentos
  /// na conta bancária configurada. Não duplica dias.
  ///
  /// Observação: feriados ainda dependem de um calendário; por enquanto, a flag
  /// é persistida, mas não filtra dias além de fim de semana.
  Future<int> processarAteHoje({
    required int idCarteira,
    required String nomeCarteira,
    double? taxaDiariaFixa,
    double aporteFixo = 0,
  }) async {
    final cfg = await _cfgRepo.porCarteira(idCarteira);
    if (cfg == null) return 0;

    final idConta = cfg.idContaBancaria;
    if (idConta == null) return 0;
    if (cfg.saldoBase <= 0) return 0;

    final hoje = DateTime.now();
    final diaHoje = DateTime(hoje.year, hoje.month, hoje.day);

    final ultima = await _rendRepo.ultimaDataProcessada(idCarteira);
    var dia = ultima == null
        ? DateTime(cfg.criadoEm.year, cfg.criadoEm.month, cfg.criadoEm.day)
        : DateTime(ultima.year, ultima.month, ultima.day)
            .add(const Duration(days: 1));

    // não cria lançamento no mesmo dia do "criadoEm" se for hoje e ainda não tiver taxa;
    // mas como o cálculo é automático, permitimos.

    // saldo (principal) simulado; no futuro pode vir de movimentos.
    var saldo = cfg.saldoBase;
    int gerados = 0;

    while (!dia.isAfter(diaHoje)) {
      final diaRef = DateTime(dia.year, dia.month, dia.day);

      // CDI rende apenas em dias úteis. No fim de semana:
      // - se "considerar fim de semana" estiver desligado → pula o dia
      // - se estiver ligado → registra o dia no histórico com rendimento 0 (sem lançamento)
      if (_ehFimDeSemana(diaRef)) {
        if (!cfg.considerarFimSemana) {
          dia = dia.add(const Duration(days: 1));
          continue;
        }

        final pctWeekend = taxaDiariaFixa != null
            ? (taxaDiariaFixa * 100.0)
            : (saldo <= cfg.limiteFaixa)
                ? cfg.pctAteLimite
                : cfg.pctAcimaLimite;
        await _rendRepo.inserir(
          idCarteira: idCarteira,
          data: diaRef,
          base: saldo,
          pctCdi: pctWeekend,
          rendimentoValor: 0,
          idLancamento: null,
        );
        dia = dia.add(const Duration(days: 1));
        continue;
      }

      // TODO(feriados): quando houver calendário, aplicar filtro aqui se !cfg.considerarFeriados

      final pct =
          (saldo <= cfg.limiteFaixa) ? cfg.pctAteLimite : cfg.pctAcimaLimite;

      final double taxaDiaria;
      final double pctParaHistorico;
      if (taxaDiariaFixa != null) {
        taxaDiaria = taxaDiariaFixa;
        pctParaHistorico = taxaDiariaFixa * 100.0;
      } else {
        final cdiBase = cfg.cdiBaseAnual;
        final cdiEfetivoAnual = cdiBase * (pct / 100.0);
        if (cdiEfetivoAnual <= 0) {
          dia = dia.add(const Duration(days: 1));
          continue;
        }

        // Converte CDI anual (%) para taxa diária com base na quantidade de dias do mês.
        // Se "considerar fim de semana" estiver desligado, usamos somente dias úteis.
        final diasMes = _diasNoMes(
          diaRef,
          incluirFimDeSemana: cfg.considerarFimSemana,
        ).toDouble();
        taxaDiaria =
            math.pow(1 + (cdiEfetivoAnual / 100.0), 1 / diasMes) - 1;
        pctParaHistorico = pct;
      }

      final rendimento = (saldo + aporteFixo) * taxaDiaria;
      if (rendimento <= 0.000001) {
        dia = dia.add(const Duration(days: 1));
        continue;
      }

      final lanc = Lancamento(
        id: null,
        valor: rendimento,
        descricao: 'Rendimento CDI — $nomeCarteira',
        formaPagamento: FormaPagamento.debito,
        dataHora: diaRef,
        pagamentoFatura: false,
        pago: true,
        dataPagamento: diaRef,
        tipoMovimento: TipoMovimento.receita,
        idConta: idConta,
      );

      final idLanc = await _lancRepo.salvar(lanc);

      await _rendRepo.inserir(
        idCarteira: idCarteira,
        data: diaRef,
        base: saldo,
        pctCdi: pctParaHistorico,
        rendimentoValor: rendimento,
        idLancamento: idLanc,
      );

      saldo += rendimento;
      gerados += 1;
      dia = dia.add(const Duration(days: 1));
    }

    return gerados;
  }
}

