import 'package:flutter/material.dart';

/// Espaço extra no fim de listas roláveis para o conteúdo não ficar sob a
/// barra de navegação do Android e sob a área típica do FAB.
double listScrollBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  const fabHeight = 56.0;
  const fabMargin = 16.0;
  const comfort = 16.0;
  return mq.viewPadding.bottom + fabHeight + fabMargin + comfort;
}

/// Soma [listScrollBottomInset] ao `bottom` de um [EdgeInsets] já usado na lista.
EdgeInsets listViewPaddingWithBottomInset(
  BuildContext context,
  EdgeInsets base,
) {
  return base.copyWith(bottom: base.bottom + listScrollBottomInset(context));
}

/// Faixa típica do FAB + folga, para somar quando o padding inferior já inclui
/// safe area (ex.: bottom sheet com `padding.bottom`, drawer com [SafeArea]).
double listExtraScrollEndPadding() {
  const fabHeight = 56.0;
  const fabMargin = 16.0;
  const comfort = 16.0;
  return fabHeight + fabMargin + comfort;
}
