import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upchat/core/utils/error_mapper.dart';

void main() {
  group('ErrorMapper.authentication', () {
    test('masque CONFIGURATION_NOT_FOUND à la création de compte', () {
      final result = ErrorMapper.authentication(
        FirebaseAuthException(
          code: 'configuration-not-found',
          message: 'CONFIGURATION_NOT_FOUND',
        ),
        isGoogle: false,
        isCreatingAccount: true,
      );

      expect(
        result.message,
        'Création de compte indisponible pour le moment. Réessaie plus tard.',
      );
      expect(result.message, isNot(contains('CONFIGURATION_NOT_FOUND')));
    });

    test('masque le code 10 Google derrière une action e-mail', () {
      final result = ErrorMapper.authentication(
        PlatformException(code: 'sign_in_failed', message: 'ApiException: 10'),
        isGoogle: true,
        isCreatingAccount: false,
      );

      expect(result.message, 'Connexion Google indisponible pour le moment.');
      expect(result.action, AuthRecoveryAction.useEmail);
      expect(result.message, isNot(contains('10')));
    });

    test('propose la connexion si l’e-mail existe déjà', () {
      final result = ErrorMapper.authentication(
        FirebaseAuthException(code: 'email-already-in-use'),
        isGoogle: false,
        isCreatingAccount: true,
      );

      expect(result.action, AuthRecoveryAction.signIn);
      expect(result.message, contains('déjà un compte'));
    });
  });
}
