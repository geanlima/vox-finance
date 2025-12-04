// lib/ui/data/modules/usuarios/usuario_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:vox_finance/ui/data/database/database_initializer.dart';
import 'package:vox_finance/ui/data/models/usuario.dart';

class UsuarioRepository {
  Future<Database> get _db async => DatabaseInitializer.initialize();

  Future<void> salvar(Usuario usuario) async {
    final db = await _db;
    await db.insert(
      'usuarios',
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Usuario?> login(String email, String senha) async {
    final db = await _db;
    final result = await db.query(
      'usuarios',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Usuario.fromMap(result.first);
  }

  Future<Usuario?> obterPrimeiro() async {
    final db = await _db;
    final result = await db.query('usuarios', limit: 1);
    if (result.isEmpty) return null;
    return Usuario.fromMap(result.first);
  }

  Future<void> limpar() async {
    final db = await _db;
    await db.delete('usuarios');
  }
}
