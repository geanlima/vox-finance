import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> ensureInitialized() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ se já existe, não inicializa de novo
    if (Firebase.apps.isNotEmpty) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // ✅ hot restart / estado estranho: se for duplicate-app, ignora
      if (e.code == 'duplicate-app') return;
      rethrow;
    }
  }
}
