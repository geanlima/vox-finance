// ignore_for_file: unused_field

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Serviço responsável por salvar/restaurar backup na nuvem (Firebase Firestore)
class BackupService {
  BackupService._internal();
  static final BackupService instance = BackupService._internal();

  factory BackupService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Salva TODOS os dados locais do usuário na nuvem.
  /// (Por enquanto só um esqueleto para não quebrar o app)
  Future<void> salvarTudo(String userId) async {
    debugPrint('[BackupService] salvarTudo($userId) ainda não implementado.');
    // Exemplo de estrutura planejada:
    // users/{userId}/lancamentos
    // users/{userId}/contas
    // users/{userId}/cartoes
  }

  /// Restaura TODOS os dados da nuvem para o SQLite.
  /// (Por enquanto só um esqueleto para não quebrar o app)
  Future<void> restaurarTudo(String userId) async {
    debugPrint(
      '[BackupService] restaurarTudo($userId) ainda não implementado.',
    );
  }
}
