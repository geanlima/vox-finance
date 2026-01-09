// ignore_for_file: use_build_context_synchronously, duplicate_ignore, unused_element

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:vox_finance/ui/core/enum/categoria.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';
import 'package:vox_finance/ui/core/service/firebase_auth_service.dart';
import 'package:vox_finance/ui/data/models/lancamento.dart';

/// Abre o bottom sheet de voz e retorna o texto reconhecido
Future<String?> mostrarBottomSheetVoz({
  required BuildContext context,
  required stt.SpeechToText speech,
}) async {
  String textoReconhecido = '';
  bool ouvindo = false;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> iniciar() async {
            if (ouvindo) return;
            ouvindo = true;
            setModalState(() {});

            await speech.listen(
              localeId: 'pt_BR',
              onResult: (result) {
                setModalState(() {
                  textoReconhecido = result.recognizedWords;
                });
              },
            );
          }

          Future<void> parar() async {
            await speech.stop();
            ouvindo = false;
            setModalState(() {});
          }

          if (!ouvindo) {
            // ignore: discarded_futures
            iniciar();
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Fale algo como:\n"gastei 50 reais no mercado no débito"',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      textoReconhecido.isEmpty
                          ? 'Aguardando sua fala...'
                          : textoReconhecido,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await parar();
                        Navigator.pop(context, null);
                      },
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(ouvindo ? Icons.mic : Icons.mic_none),
                      label: Text(ouvindo ? 'Parar e usar' : 'Ouvir de novo'),
                      onPressed: () async {
                        if (ouvindo) {
                          await parar();
                          Navigator.pop(context, textoReconhecido);
                        } else {
                          await iniciar();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// ✅ Logout unificado: funciona para login local e Firebase/Google
Future<void> realizarLogout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final loginType = prefs.getString('loginType'); // 'firebase' ou 'local'

  // 1) Se for login via Firebase, desloga do Firebase
  if (loginType == 'firebase') {
    await FirebaseAuthService.instance.signOut();
  }

  // 2) Limpa flags de login
  await prefs.setBool('isLoggedIn', false);
  await prefs.remove('loginType');

  // 3) Volta para a rota de login (que no main.dart aponta p/ LoginUnificadoPage)
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}

/// Interpreta um comando em linguagem natural e devolve um Lancamento
Lancamento? interpretarComandoVoz(String texto) {
  if (texto.isEmpty) return null;

  final lower = texto.toLowerCase();

  FormaPagamento forma = FormaPagamento.dinheiro;
  bool pagamentoFatura = false;

  if (lower.contains('débito') || lower.contains('debito')) {
    forma = FormaPagamento.debito;
  } else if (lower.contains('crédito') || lower.contains('credito')) {
    forma = FormaPagamento.credito;
  } else if (lower.contains('pix')) {
    forma = FormaPagamento.pix;
  } else if (lower.contains('boleto')) {
    forma = FormaPagamento.boleto;
  } else if (lower.contains('dinheiro')) {
    forma = FormaPagamento.dinheiro;
  }

  if (lower.contains('fatura')) {
    pagamentoFatura = true;
  }

  final match = RegExp(r'(\d+[.,]?\d*)').firstMatch(lower);
  if (match == null) return null;

  var valorStr = match.group(1)!;
  valorStr = valorStr.replaceAll('.', '').replaceAll(',', '.');

  final valor = double.tryParse(valorStr);
  if (valor == null || valor <= 0) return null;

  String descricao = lower;
  descricao = descricao.replaceFirst(match.group(1)!, '');
  descricao =
      descricao
          .replaceAll('reais', '')
          .replaceAll('real', '')
          .replaceAll('debito', '')
          .replaceAll('débito', '')
          .replaceAll('credito', '')
          .replaceAll('crédito', '')
          .replaceAll('dinheiro', '')
          .replaceAll('boleto', '')
          .replaceAll('no pix', '')
          .replaceAll('pix', '')
          .replaceAll('gastei', '')
          .replaceAll('eu', '')
          .replaceAll('paguei', '')
          .replaceAll('fatura', '')
          .trim();

  if (descricao.isEmpty) {
    descricao = 'Sem descrição';
  } else {
    descricao = descricao[0].toUpperCase() + descricao.substring(1);
  }

  final categoria = CategoriaService.fromDescricao(descricao);

  return Lancamento(
    valor: valor,
    descricao: descricao,
    formaPagamento: forma,
    dataHora: DateTime.now(),
    pagamentoFatura: pagamentoFatura,
    categoria: categoria,
    pago: true,
    dataPagamento: DateTime.now(),
  );
}
