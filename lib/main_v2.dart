import 'package:flutter/material.dart';
import 'v2/app/vox_finance_v2_app.dart';
import 'v2/app/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InjectorV2.init();
  runApp(const VoxFinanceV2App());
}
