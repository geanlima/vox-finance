// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:vox_finance/ui/core/enum/forma_pagamento.dart';

/// De onde vem a imagem
enum FonteImagem { camera, galeria }

class ResultadoComprovante {
  final double? valor;
  final String? descricao;
  final FormaPagamento? forma;

  ResultadoComprovante({
    required this.valor,
    required this.descricao,
    required this.forma,
  });
}

/// Componente (bottom sheet) para escolher CAMERA ou GALERIA
Future<FonteImagem?> escolherFonteImagem(BuildContext context) {
  return showModalBottomSheet<FonteImagem>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Usar câmera'),
              onTap: () => Navigator.pop(context, FonteImagem.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, FonteImagem.galeria),
            ),
          ],
        ),
      );
    },
  );
}

/// Lê o comprovante a partir de CAMERA ou GALERIA
Future<ResultadoComprovante?> lerComprovante({
  required BuildContext context,
  required ImagePicker picker,
  required FonteImagem fonte,
}) async {
  try {
    final picked = await picker.pickImage(
      source:
          fonte == FonteImagem.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked == null) return null;

    final inputImage = InputImage.fromFilePath(picked.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final texto = recognizedText.text;

    final valor = _extrairValorDeTexto(texto);
    final descricao = _extrairDescricao(texto);
    final forma = _extrairFormaPagamento(texto);

    return ResultadoComprovante(
      valor: valor,
      descricao: descricao,
      forma: forma,
    );
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erro ao ler comprovante: $e')));
    return null;
  }
}

// ---------- helpers privados ----------

double? _extrairValorDeTexto(String texto) {
  final regex = RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{2})');
  double? maior;

  for (final match in regex.allMatches(texto)) {
    final raw = match.group(0)!;
    var clean = raw.replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(clean);
    if (valor != null && (maior == null || valor > maior)) {
      maior = valor;
    }
  }

  return maior;
}

String? _extrairDescricao(String texto) {
  final linhas =
      texto
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

  if (linhas.isEmpty) return null;

  for (final l in linhas) {
    final upper = l.toUpperCase();
    if (upper.contains('TOTAL')) continue;
    if (upper.contains('R\$')) continue;
    if (RegExp(r'\d').hasMatch(l)) continue;
    return l;
  }

  return linhas.first;
}

FormaPagamento? _extrairFormaPagamento(String texto) {
  final up = texto.toUpperCase();

  if (up.contains('CRÉDITO') || up.contains('CREDITO')) {
    return FormaPagamento.credito;
  }
  if (up.contains('DÉBITO') || up.contains('DEBITO')) {
    return FormaPagamento.debito;
  }
  if (up.contains('PIX')) {
    return FormaPagamento.pix;
  }
  if (up.contains('BOLETO')) {
    return FormaPagamento.boleto;
  }
  if (up.contains('DINHEIRO') ||
      up.contains('ESPÉCIE') ||
      up.contains('ESPECIE')) {
    return FormaPagamento.dinheiro;
  }

  return null;
}
