import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._internal();
  static final GoogleAuthService instance = GoogleAuthService._internal();

  factory GoogleAuthService() => instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> loginWithGoogle() async {
    // 1️⃣ Seleciona conta
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    // 2️⃣ Pega as credenciais
    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 3️⃣ Faz login no Firebase
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
