import 'package:flutter/material.dart';

class EscolherVersaoPage extends StatelessWidget {
  final Future<void> Function(String versao) onEscolheu;

  const EscolherVersaoPage({super.key, required this.onEscolheu});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher versão')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Qual versão você deseja usar?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => onEscolheu('v1'),
                  child: const Text('V1'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => onEscolheu('v2'),
                  child: const Text('V2'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dica: você pode trocar depois em Configurações.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
