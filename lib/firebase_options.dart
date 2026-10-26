// Fichier de configuration Firebase injecté par GitHub Actions.
// Les valeurs sont fournies par --dart-define ou remplacées par le secret
// FIREBASE_OPTIONS_DART_BASE64. Aucun secret serveur n'est stocké ici.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  // Configuration publique de l'application Web UpChat.
  static const _webApiKey = 'AIzaSyABzrVAHIyHs5u2usw36IJ7rn9EXRI7PbE';
  static const _webAuthDomain = 'upchat-android.firebaseapp.com';
  static const _webProjectId = 'upchat-android';
  static const _webStorageBucket = 'upchat-android.firebasestorage.app';
  static const _webMessagingSenderId = '451915075042';
  static const _webAppId = '1:451915075042:web:8638d4392781d5c4937dbb';
  static const _webMeasurementId = 'G-LRSXTTBDHY';

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

  static bool get isConfigured => kIsWeb
      ? _webApiKey.isNotEmpty && _webAppId.isNotEmpty && _webProjectId.isNotEmpty
      : apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('Firebase configuration is missing');
    }
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: _webApiKey,
        appId: _webAppId,
        messagingSenderId: _webMessagingSenderId,
        projectId: _webProjectId,
        authDomain: _webAuthDomain,
        storageBucket: _webStorageBucket,
        measurementId: _webMeasurementId,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        );
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }
}
