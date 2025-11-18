import 'package:isar/isar.dart';

part 'conta_pagar.g.dart';

@collection
class ContaPagar {
  Id id = Isar.autoIncrement;

  late String descricao;
  late double valor;
  late DateTime dataVencimento;

  bool pago = false;
  DateTime? dataPagamento;

  int? parcelaNumero; // 1..N
  int? parcelaTotal; // N
  String? grupoParcelas; // mesmo grupo para todas as parcelas da compra
}
