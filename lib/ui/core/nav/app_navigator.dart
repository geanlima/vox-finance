import 'package:flutter/material.dart';
import 'package:vox_finance/v2/presentation/pages/gate/app_gate_page.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static NavigatorState get _nav {
    final nav = key.currentState;
    if (nav == null) {
      throw Exception(
        'AppNavigator ainda não está pronto (navigatorKey null).',
      );
    }
    return nav;
  }

  static Future<void> goToGateClearingStack() async {
    _nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppGatePage()),
      (_) => false,
    );
  }
}
