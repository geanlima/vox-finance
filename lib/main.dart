import 'package:flutter/material.dart';
import 'bootstrap/firebase_bootstrap.dart';
import 'package:vox_finance/v2/presentation/pages/gate/app_gate_page.dart';
import 'package:vox_finance/ui/core/nav/app_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.ensureInitialized();
  runApp(const VoxApp());
}

class VoxApp extends StatelessWidget {
  const VoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNavigator.key, // ✅ AQUI
      debugShowCheckedModeBanner: false,
      home: const AppGatePage(),
    );
  }
}
