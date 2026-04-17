// ignore_for_file: public_member_api_docs

class FaturaGeracaoOpcao {
  final int idCartao;
  final String cartaoLabel;
  final int anoReferencia; // mês de fechamento (referência)
  final int mesReferencia; // mês de fechamento (referência)
  final int anoVencimento;
  final int mesVencimento;

  const FaturaGeracaoOpcao({
    required this.idCartao,
    required this.cartaoLabel,
    required this.anoReferencia,
    required this.mesReferencia,
    required this.anoVencimento,
    required this.mesVencimento,
  });

  String get referenciaLabel => '${mesReferencia.toString().padLeft(2, '0')}/$anoReferencia';
  String get vencimentoLabel => '${mesVencimento.toString().padLeft(2, '0')}/$anoVencimento';

  String get key => '$idCartao:$anoReferencia-$mesReferencia';
}

