import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// États compréhensibles par l’interface pour l’authentification locale.
enum BiometricAuthStatus {
  available,
  authenticated,
  cancelled,
  unavailable,
  notEnrolled,
  lockedOut,
  failed,
}

/// Résultat d’une vérification ou d’une demande biométrique.
class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String message;

  const BiometricAuthResult(this.status, this.message);

  bool get isSuccess => status == BiometricAuthStatus.authenticated;
  bool get isAvailable => status == BiometricAuthStatus.available;
}

/// Pont vers l’authentification biométrique fournie par l’appareil.
///
/// Les empreintes et données faciales ne quittent jamais le système Android ou
/// iOS. UpChat ne reçoit qu’un résultat oui/non du système d’exploitation.
class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  /// Vérifie que l’appareil peut fournir une authentification locale.
  /// Le code, schéma ou mot de passe reste un secours valide lorsque la
  /// biométrie n’est pas enrôlée, comme sur l’écran de verrouillage système.
  Future<BiometricAuthResult> checkAvailability() async {
    if (kIsWeb) {
      return const BiometricAuthResult(
        BiometricAuthStatus.unavailable,
        'Le verrou biométrique est disponible dans l’application mobile.',
      );
    }

    try {
      final isSupported = await _localAuthentication.isDeviceSupported();
      if (!isSupported) {
        return const BiometricAuthResult(
          BiometricAuthStatus.unavailable,
          'La vérification de l’appareil est indisponible. Utilise un téléphone protégé.',
        );
      }
      return const BiometricAuthResult(
        BiometricAuthStatus.available,
        'La biométrie ou le code du téléphone sont disponibles.',
      );
    } on LocalAuthException catch (error) {
      return _fromException(error);
    } catch (_) {
      return const BiometricAuthResult(
        BiometricAuthStatus.unavailable,
        'La biométrie est momentanément indisponible. Réessaie plus tard.',
      );
    }
  }

  /// Demande uniquement une biométrie inscrite (sans code PIN de secours).
  Future<BiometricAuthResult> authenticate() async {
    final availability = await checkAvailability();
    if (!availability.isAvailable) return availability;

    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Confirme ton identité pour ouvrir UpChat.',
        // Autorise le code, le schéma ou le mot de passe du téléphone
        // lorsque la biométrie est indisponible ou temporairement bloquée.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        return const BiometricAuthResult(
          BiometricAuthStatus.authenticated,
          'Identité confirmée.',
        );
      }
      return const BiometricAuthResult(
        BiometricAuthStatus.cancelled,
        'Authentification annulée.',
      );
    } on LocalAuthException catch (error) {
      return _fromException(error);
    } catch (_) {
      return const BiometricAuthResult(
        BiometricAuthStatus.failed,
        'La vérification est indisponible. Utilise le code de ton téléphone.',
      );
    }
  }

  BiometricAuthResult _fromException(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return const BiometricAuthResult(
          BiometricAuthStatus.unavailable,
          'La biométrie n’est pas prise en charge sur cet appareil.',
        );
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return const BiometricAuthResult(
          BiometricAuthStatus.notEnrolled,
          'Ajoute une empreinte ou un visage dans les réglages du téléphone avant de réessayer.',
        );
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return const BiometricAuthResult(
          BiometricAuthStatus.lockedOut,
          'La biométrie est temporairement verrouillée par le téléphone. Attends un instant puis réessaie.',
        );
      default:
        return const BiometricAuthResult(
          BiometricAuthStatus.failed,
          'La vérification est indisponible. Utilise le code de ton téléphone.',
        );
    }
  }
}
