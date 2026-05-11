import 'package:flutter/material.dart';
import 'package:vox_finance/ui/core/service/manutencao_sqlite_upload_service.dart';

Future<void> mostrarSqliteImportacaoResultadoDialog(
  BuildContext context,
  SqliteImportacaoResultado r,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Sincronização com a API'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r.resumoLinha,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (r.erros.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  r.erros.join('\n'),
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${r.registrosPorTabela.length} tabela(s) no resumo',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Progresso (${r.logs.length} eventos)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    itemCount: r.logs.length,
                    itemBuilder: (c, i) {
                      final l = r.logs[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          l.linhaResumida,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: cs.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
