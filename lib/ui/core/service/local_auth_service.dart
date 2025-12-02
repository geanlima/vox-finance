import 'package:vox_finance/ui/data/modules/usuarios/usuario_repository.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';

/// Serviço responsável pelo login LOCAL (SQLite)
class LocalAuthService {
  LocalAuthService._internal();
  final UsuarioRepository _repository = UsuarioRepository();
  static final LocalAuthService instance = LocalAuthService._internal();

  factory LocalAuthService() => instance;

  /// Faz login usando o banco local (DbService / SQLite)
  Future<Usuario?> loginLocal(String email, String senha) async {
    final usuario = await _repository.login(email, senha);
    return usuario;
  }
}
