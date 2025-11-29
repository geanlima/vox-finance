// lib/ui/core/utils/date_utils.dart

class DateUtilsVox {
  static const List<String> _mesesAbreviados = [
    '',
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  /// Retorna o nome abreviado do mês (1 a 12).
  /// Se for um valor inválido, retorna string vazia.
  static String mesNome(int mes) {
    if (mes < 1 || mes > 12) return '';
    return _mesesAbreviados[mes];
  }
}
