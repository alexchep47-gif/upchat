import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

enum AuthRecoveryAction { retry, useEmail, signIn, forgotPassword, continueOffline }

class UserFacingError {
  const UserFacingError({required this.message, this.action});

  final String message;
  final AuthRecoveryAction? action;
}

/// Traduit les erreurs techniques en messages français actionnables.
/// Les détails d’exception restent destinés aux journaux et au diagnostic.
class ErrorMapper {
  static UserFacingError authentication(
    Object error, {
    required bool isGoogle,
    required bool isCreatingAccount,
  }) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return const UserFacingError(
            message: 'Pas de réseau. Vérifie ta connexion puis réessaie.',
            action: AuthRecoveryAction.retry,
          );
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return const UserFacingError(
            message: 'E-mail ou mot de passe incorrect.',
            action: AuthRecoveryAction.forgotPassword,
          );
        case 'email-already-in-use':
          return const UserFacingError(
            message: 'Cet e-mail possède déjà un compte UpChat.',
            action: AuthRecoveryAction.signIn,
          );
        case 'weak-password':
          return const UserFacingError(
            message:
                'Choisis un mot de passe d’au moins 8 caractères avec une lettre et un chiffre.',
          );
        case 'too-many-requests':
          return const UserFacingError(
            message:
                'Trop de tentatives. Attends quelques minutes avant de réessayer.',
          );
        case 'account-exists-with-different-credential':
          return const UserFacingError(
            message:
                'Un compte existe déjà avec une autre méthode de connexion.',
            action: AuthRecoveryAction.useEmail,
          );
        case 'operation-not-allowed':
        case 'configuration-not-found':
        case 'internal-error':
          return UserFacingError(
            message: isCreatingAccount
                ? 'Création de compte indisponible pour le moment. Réessaie plus tard.'
                : 'Connexion indisponible pour le moment. Réessaie plus tard.',
            action: AuthRecoveryAction.continueOffline,
          );
        default:
          return UserFacingError(
            message: isGoogle
                ? 'Connexion Google indisponible pour le moment.'
                : 'Connexion indisponible pour le moment. Réessaie plus tard.',
            action: AuthRecoveryAction.continueOffline,
          );
      }
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('configuration_not_found') ||
        raw.contains('configuration-not-found')) {
      return UserFacingError(
        message: isCreatingAccount
            ? 'Création de compte indisponible pour le moment. Réessaie plus tard.'
            : 'Connexion indisponible pour le moment. Réessaie plus tard.',
        action: AuthRecoveryAction.continueOffline,
      );
    }
    if (error is PlatformException ||
        raw.contains('sign_in_failed') ||
        raw.contains('api_exception: 10')) {
      return const UserFacingError(
        message: 'Connexion Google indisponible pour le moment.',
        action: AuthRecoveryAction.continueOffline,
      );
    }

    return UserFacingError(
      message: isGoogle
          ? 'Connexion Google indisponible pour le moment.'
          : 'Connexion indisponible pour le moment. Réessaie plus tard.',
      action: AuthRecoveryAction.continueOffline,
    );
  }
}
