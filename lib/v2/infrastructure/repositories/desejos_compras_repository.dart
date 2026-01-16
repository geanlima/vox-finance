import 'package:sqflite/sqflite.dart';

class DesejoCompraRow {
  final int id;
  final String produto;
  final String? categoria;
  final double valor;
  final int prioridade; // 1..3
  final String? linkCompra;
  final bool comprado;

  DesejoCompraRow({
    required this.id,
    required this.produto,
    required this.categoria,
    required this.valor,
    required this.prioridade,
    required this.linkCompra,
    required this.comprado,
  });

  String get prioridadeLabel {
    switch (prioridade) {
      case 1:
        return '1 - Essencial';
      case 2:
        return '2 - Importante';
      default:
        return '3 - Desejo';
    }
  }

  String get statusLabel => comprado ? 'Comprei' : 'Não comprei';

  factory DesejoCompraRow.fromMap(Map<String, Object?> m) {
    return DesejoCompraRow(
      id: (m['id'] as int),
      produto: (m['produto'] as String),
      categoria: m['categoria'] as String?,
      valor: (m['valor'] as num).toDouble(),
      prioridade: (m['prioridade'] as int?) ?? 2,
      linkCompra: m['link_compra'] as String?,
      comprado: (m['comprado'] as int? ?? 0) == 1,
    );
  }
}

class DesejosComprasRepository {
  final Database db;
  DesejosComprasRepository(this.db);

  Future<List<DesejoCompraRow>> listar() async {
    final r = await db.query(
      'desejos_compras',
      orderBy: 'comprado ASC, prioridade ASC, id DESC',
    );
    return r.map(DesejoCompraRow.fromMap).toList();
  }

  Future<int> inserir({
    required String produto,
    String? categoria,
    double valor = 0,
    int prioridade = 2,
    String? linkCompra,
  }) async {
    return db.insert('desejos_compras', {
      'produto': produto.trim(),
      'categoria': categoria?.trim(),
      'valor': valor,
      'prioridade': prioridade,
      'link_compra': linkCompra?.trim(),
      'comprado': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> atualizar({
    required int id,
    required String produto,
    String? categoria,
    required double valor,
    required int prioridade,
    String? linkCompra,
  }) async {
    await db.update(
      'desejos_compras',
      {
        'produto': produto.trim(),
        'categoria': categoria?.trim(),
        'valor': valor,
        'prioridade': prioridade,
        'link_compra': linkCompra?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> setComprado(int id, bool comprado) async {
    await db.update(
      'desejos_compras',
      {
        'comprado': comprado ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> remover(int id) async {
    await db.delete('desejos_compras', where: 'id=?', whereArgs: [id]);
  }
}
