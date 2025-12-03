
class DestinoRenda {
  final int? id;
  final int idFonte;
  final String nome;
  final double percentual;
  final bool ativo; // 👈 novo

  const DestinoRenda({
    this.id,
    required this.idFonte,
    required this.nome,
    required this.percentual,
    this.ativo = true,
  });

  DestinoRenda copyWith({
    int? id,
    int? idFonte,
    String? nome,
    double? percentual,
    bool? ativo,
  }) {
    return DestinoRenda(
      id: id ?? this.id,
      idFonte: idFonte ?? this.idFonte,
      nome: nome ?? this.nome,
      percentual: percentual ?? this.percentual,
      ativo: ativo ?? this.ativo,
    );
  }

  factory DestinoRenda.fromMap(Map<String, dynamic> map) {
    return DestinoRenda(
      id: map['id'] as int?,
      idFonte: map['id_fonte'] as int,
      nome: map['nome'] as String,
      percentual: (map['percentual'] as num).toDouble(),
      ativo: (map['ativo'] as int? ?? 1) == 1, // se tiver coluna ativo no banco
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_fonte': idFonte,
      'nome': nome,
      'percentual': percentual,
      'ativo': ativo ? 1 : 0,
    };
  }
}
