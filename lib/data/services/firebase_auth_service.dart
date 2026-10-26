import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Authentification distante optionnelle. Le mode hors ligne ne dépend pas
/// de Firebase et reste utilisable sans compte.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  FirebaseAuth? _auth;
  String? lastError;

  bool get isConfigured => _auth != null;
  User? get currentUser => _auth?.currentUser;

  Future<bool> initialize() async {
    if (_auth != null) return true;
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (_) {
          // Android utilise google-services.json et iOS son plist injecté par CI.
          // Le Web doit obligatoirement recevoir firebase_options.dart.
          if (kIsWeb) rethrow;
          await Firebase.initializeApp();
        }
      }
      _auth = FirebaseAuth.instance;
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'La connexion à distance est momentanément indisponible. UpChat reste utilisable hors ligne.';
      return false;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!await initialize()) return null;
    return _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> createAccount(String email, String password) async {
    if (!await initialize()) return null;
    return _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!await initialize()) return null;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      return _auth!.signInWithPopup(provider);
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final auth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    return _auth!.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    await GoogleSignIn().signOut();
  }
}
