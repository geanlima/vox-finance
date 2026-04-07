import 'package:flutter/material.dart';
import 'package:vox_finance/ui/pages/integracao/associar_cartao_credito_page.dart';
import 'package:vox_finance/ui/pages/integracao/faturas_cartao_page.dart';
import 'package:vox_finance/ui/widgets/app_drawer.dart';

/// Hub de integração: a partir daqui abrimos cada tipo de associação/configuração.
class AssociacaoPage extends StatelessWidget {
  const AssociacaoPage({super.key});

  static const routeName = '/integracao/associacao';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Associação'),
      ),
      drawer: const AppDrawer(currentRoute: AssociacaoPage.routeName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Escolha o que deseja configurar. As associações são usadas na sincronização.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AssociarCartaoCreditoPage(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        Icons.credit_card,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Associar cartão de crédito',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Relacione os cartões recebidos na integração com os cadastrados no aplicativo.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, FaturasCartaoPage.routeName);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faturas de cartão',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Consulte faturas por cartão e mês, com lançamentos e totais.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
