// lib/ui/data/models/usuario.dart

class Usuario {
  final int id;
  final String email;
  final String nome;
  final String senha;
  final String? fotoPath;
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.email,
    required this.nome,
    required this.senha,
    this.fotoPath,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nome': nome,
      'senha': senha,
      'foto_path': fotoPath,                // coluna no banco
      'criado_em': criadoEm.toIso8601String(),
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int,
      email: map['email'] ?? '',
      nome: map['nome'] ?? '',
      senha: map['senha'] ?? '',
      fotoPath: map['foto_path'] as String?, // pode ser null
      criadoEm: DateTime.parse(map['criado_em'] as String),
    );
  }
}
