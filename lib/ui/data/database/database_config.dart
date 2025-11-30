// lib/ui/data/database/database_config.dart
// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseConfig {
  /// Nome do arquivo do banco
  static const String dbName = 'vox_finance.db';

  /// Versão atual do schema (a mesma 15 que você já usa)
  static const int dbVersion = 16;

  /// Retorna o caminho completo do arquivo do banco
  static Future<String> getDatabasePath() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbName);
  }
}
