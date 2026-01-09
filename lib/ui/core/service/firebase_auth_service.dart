import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseAuthService {
  FirebaseAuthService._();
  static final instance = FirebaseAuthService._();

  final _auth = FirebaseAuth.instance;

  Future<User?> signInWithGoogle({bool forceAccountPicker = true}) async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

    if (forceAccountPicker) {
      // ✅ limpa sessão para obrigar o seletor de contas
      await googleSignIn.signOut();

      // (opcional, mais forte) remove a permissão e força escolher de novo
      // await googleSignIn.disconnect();
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // cancelado

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn()
        .signOut(); // garante que a sessão do Google saia também
  }
}
