import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // 👈 IMPORTANTE

class FirebaseAuthService {
  FirebaseAuthService._internal();
  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  factory FirebaseAuthService() => instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =========================================
  // LOGIN COM E-MAIL / SENHA (Firebase)
  // =========================================
  Future<User?> loginWithEmailPassword(String email, String senha) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return cred.user;
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // =========================================
  // LOGIN COM GOOGLE
  // =========================================
  Future<User?> signInWithGoogle() async {
    // Abre a tela de escolha de conta do Google
    final googleUser = await GoogleSignIn().signIn();

    // Se o usuário cancelar, volta null
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    return userCred.user;
  }

  User? get currentUser => _auth.currentUser;

  Future<void> logout() async {
    await _auth.signOut();
    await GoogleSignIn().signOut(); // opcional, pra sair do Google também
  }
}
