import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class VoxFinanceV2App extends StatelessWidget {
  const VoxFinanceV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoxFinance V2',
      theme: AppThemeV2.light(),
      initialRoute: AppRouterV2.home,
      routes: AppRouterV2.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
