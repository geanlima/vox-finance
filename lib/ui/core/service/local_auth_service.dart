import 'package:vox_finance/ui/data/service/db_service.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';

/// Serviço responsável pelo login LOCAL (SQLite)
class LocalAuthService {
  LocalAuthService._internal();
  static final LocalAuthService instance = LocalAuthService._internal();

  factory LocalAuthService() => instance;

  /// Faz login usando o banco local (DbService / SQLite)
  Future<Usuario?> loginLocal(String email, String senha) async {
    final usuario = await DbService.instance.loginUsuario(email, senha);
    return usuario;
  }
}
