class Usuario {
  final int id;
  final String email;
  final String nome;
  final String senha;      // 👈 importante
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.email,
    required this.nome,
    required this.senha,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nome': nome,
      'senha': senha,
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      email: map['email'],
      nome: map['nome'] ?? '',
      senha: map['senha'],
      criadoEm: DateTime.parse(map['criado_em']),
    );
  }
}
