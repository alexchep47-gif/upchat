import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

/// Authentification distante optionnelle. Le mode hors ligne reste autonome.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  FirebaseAuth? _auth;
  Future<bool>? _initialization;
  String? lastError;
  String? lastTechnicalError;

  bool get isConfigured => _auth != null;
  User? get currentUser => _auth?.currentUser;

  /// Client OAuth Web requis pour échanger le jeton Google côté Firebase sur
  /// Android et iOS. La CI le transmet via GOOGLE_SERVER_CLIENT_ID.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  Future<bool> initialize() {
    if (_auth != null) return Future.value(true);
    final inProgress = _initialization;
    if (inProgress != null) return inProgress;

    final initialization = _initialize();
    _initialization = initialization.then((success) {
      if (!success) {
        _initialization = null;
      }
      return success;
    });
    return _initialization!;
  }

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (kIsWeb) {
          // Le build Web reçoit le fichier FlutterFire complet via un secret.
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          // Android/iOS lisent uniquement leur configuration native injectée
          // par la CI (google-services.json / GoogleService-Info.plist).
          await Firebase.initializeApp();
        }
      }
      _auth = FirebaseAuth.instance;
      lastError = null;
      lastTechnicalError = null;
      return true;
    } catch (error) {
      lastTechnicalError = error.toString();
      lastError =
          'Le service de connexion est indisponible pour le moment. UpChat reste utilisable hors ligne.';
      debugPrint('FirebaseAuthService.initialize: $error');
      return false;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!await initialize()) return null;
    try {
      lastError = null;
      lastTechnicalError = null;
      return await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      _rememberAuthException(error);
      rethrow;
    }
  }

  Future<UserCredential?> createAccount(String email, String password) async {
    if (!await initialize()) return null;
    try {
      lastError = null;
      lastTechnicalError = null;
      return await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      _rememberAuthException(error);
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!await initialize()) {
      throw StateError(lastError ?? 'Service de connexion indisponible.');
    }
    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      lastError = null;
      lastTechnicalError = null;
    } on FirebaseAuthException catch (error) {
      _rememberAuthException(error);
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    if (!await initialize()) {
      throw StateError(lastError ?? 'Service de connexion indisponible.');
    }
    final user = _auth!.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Aucun compte Firebase connecté.',
      );
    }
    await user.sendEmailVerification();
  }

  Future<bool> refreshEmailVerification() async {
    if (!await initialize()) return false;
    final user = _auth!.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth!.currentUser?.emailVerified ?? false;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!await initialize()) return null;
    lastError = null;
    lastTechnicalError = null;
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        return await _auth!.signInWithPopup(provider);
      }

      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _serverClientId.isNotEmpty ? _serverClientId : null,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        lastError = 'Connexion Google annulée.';
        return null;
      }
      final auth = await googleUser.authentication;
      if (auth.idToken == null && auth.accessToken == null) {
        lastTechnicalError =
            'Google Sign-In returned no ID token or access token.';
        lastError = 'Connexion Google indisponible pour le moment.';
        return null;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      return await _auth!.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      _rememberAuthException(error);
      rethrow;
    } catch (error) {
      lastTechnicalError = error.toString();
      lastError = 'Connexion Google indisponible pour le moment.';
      debugPrint('FirebaseAuthService.signInWithGoogle: $error');
      rethrow;
    }
  }

  /// Envoie le SMS sur Android/iOS. Le Web utilise signInWithPhoneNumber.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    void Function(PhoneAuthCredential credential)? verificationCompleted,
    void Function(FirebaseAuthException error)? verificationFailed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Le Web utilise signInWithPhoneNumber.');
    }
    if (!await initialize()) {
      throw StateError(lastError ?? 'Service de connexion indisponible.');
    }
    final completer = Completer<void>();
    await _auth!.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: (credential) => verificationCompleted?.call(credential),
      verificationFailed: (error) {
        _rememberAuthException(error);
        verificationFailed?.call(error);
        if (!completer.isCompleted) completer.completeError(error);
      },
      codeSent: (verificationId, _) {
        codeSent(verificationId);
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          codeSent(verificationId);
          completer.complete();
        }
      },
    );
    return completer.future;
  }

  /// Envoie le SMS Web après le contrôle reCAPTCHA Firebase.
  Future<ConfirmationResult> signInWithPhoneNumber(String phoneNumber) async {
    if (!kIsWeb) {
      throw UnsupportedError('Android/iOS utilisent verifyPhoneNumber.');
    }
    if (!await initialize()) {
      throw StateError(lastError ?? 'Service de connexion indisponible.');
    }
    return _auth!.signInWithPhoneNumber(phoneNumber);
  }

  PhoneAuthCredential credential({
    required String verificationId,
    required String smsCode,
  }) => PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

  Future<UserCredential> linkWithCredential(AuthCredential phoneCredential) async {
    if (!await initialize()) {
      throw StateError(lastError ?? 'Service de connexion indisponible.');
    }
    final user = _auth!.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Connecte-toi avant de vérifier ton numéro.',
      );
    }
    try {
      return await user.linkWithCredential(phoneCredential);
    } on FirebaseAuthException catch (error) {
      _rememberAuthException(error);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  void _rememberAuthException(FirebaseAuthException error) {
    lastTechnicalError = '${error.code}: ${error.message}';
    lastError = 'Connexion indisponible pour le moment. Réessaie plus tard.';
    debugPrint('FirebaseAuthService.auth: $lastTechnicalError');
  }
}
