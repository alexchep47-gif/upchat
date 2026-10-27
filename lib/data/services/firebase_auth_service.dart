import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Authentification distante optionnelle. Le mode hors ligne reste autonome.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  FirebaseAuth? _auth;
  String? lastError;

  bool get isConfigured => _auth != null;
  User? get currentUser => _auth?.currentUser;

  /// Client OAuth Web (requis sur Android pour obtenir un idToken valide).
  /// Défini via --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
  /// ou secret CI injecté dans firebase_options / env.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  Future<bool> initialize() async {
    if (_auth != null) return true;
    try {
      if (Firebase.apps.isEmpty) {
        try {
          if (DefaultFirebaseOptions.isConfigured) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          } else if (!kIsWeb) {
            // Android/iOS : google-services.json / GoogleService-Info.plist
            await Firebase.initializeApp();
          } else {
            throw StateError('Firebase web non configuré');
          }
        } catch (e) {
          if (kIsWeb) rethrow;
          // Dernier recours Android/iOS natif
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
        }
      }
      _auth = FirebaseAuth.instance;
      lastError = null;
      return true;
    } catch (error) {
      lastError =
          'Firebase indisponible ($error). UpChat reste utilisable hors ligne.';
      debugPrint('FirebaseAuthService.init: $error');
      return false;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!await initialize()) return null;
    try {
      lastError = null;
      return await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      lastError = e.message ?? e.code;
      rethrow;
    }
  }

  Future<UserCredential?> createAccount(String email, String password) async {
    if (!await initialize()) return null;
    try {
      lastError = null;
      return await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      lastError = e.message ?? e.code;
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!await initialize()) return null;
    lastError = null;
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth!.signInWithPopup(provider);
      }

      // Android / iOS : serverClientId = client OAuth type Web de Firebase
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId:
            _serverClientId.isNotEmpty ? _serverClientId : null,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        lastError = 'Connexion Google annulée.';
        return null;
      }
      final auth = await googleUser.authentication;
      if (auth.idToken == null && auth.accessToken == null) {
        lastError =
            'Google n’a pas renvoyé de jeton. Ajoute le SHA-1 de l’APK dans Firebase Console → Paramètres du projet → Ton app Android, puis le client OAuth Web (GOOGLE_SERVER_CLIENT_ID).';
        return null;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      return await _auth!.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      lastError = e.message ?? e.code;
      rethrow;
    } catch (e) {
      lastError = 'Google Sign-In : $e';
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
}
