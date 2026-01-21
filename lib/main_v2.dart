import 'package:flutter/material.dart';

import 'package:vox_finance/v2/app/di/injector.dart';
import 'package:vox_finance/v2/app/vox_finance_v2_app.dart';

class VoxFinanceV2Entry extends StatelessWidget {
  const VoxFinanceV2Entry({super.key});

  static final Future<void> _initFuture = InjectorV2.init();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        if (snap.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Erro ao inicializar V2:\n${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        return const VoxFinanceV2App();
      },
    );
  }
}
