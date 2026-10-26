import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      lastError = null;
      return true;
    } catch (error) {
      lastError = 'Firebase n’est pas encore configuré pour cette plateforme.';
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
