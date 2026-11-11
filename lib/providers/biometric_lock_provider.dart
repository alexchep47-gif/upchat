import 'package:flutter/foundation.dart';

import '../data/services/biometric_auth_service.dart';
import '../data/services/storage_service.dart';

/// État du verrou d’application biométrique.
///
/// L’option est volontaire : l’application reste utilisable hors ligne et sans
/// compte Firebase. L’activation exige une authentification réussie immédiate.
class BiometricLockProvider extends ChangeNotifier {
  BiometricLockProvider({BiometricAuthService? service})
    : _service = service ?? BiometricAuthService() {
    _enabled = StorageService.biometricLockEnabled;
    // Comme Ma caisse, une préférence active protège aussi l’ouverture initiale.
    _locked = _enabled;
  }

  final BiometricAuthService _service;
  bool _enabled = false;
  bool _locked = false;
  bool _authenticating = false;
  BiometricAuthResult? _lastResult;

  bool get enabled => _enabled;
  bool get isLocked => _locked;
  bool get isAuthenticating => _authenticating;
  BiometricAuthResult? get lastResult => _lastResult;

  /// Active le verrou seulement après validation par une biométrie réelle.
  Future<BiometricAuthResult> enable() async {
    final availability = await _service.checkAvailability();
    if (!availability.isAvailable) {
      _lastResult = availability;
      notifyListeners();
      return availability;
    }

    final result = await _authenticate();
    if (result.isSuccess) {
      _enabled = true;
      _locked = false;
      await StorageService.setBiometricLockEnabled(true);
      notifyListeners();
    }
    return result;
  }

  /// Désactive le verrou pour les prochains retours au premier plan.
  Future<void> disable() async {
    _enabled = false;
    _locked = false;
    _lastResult = null;
    await StorageService.setBiometricLockEnabled(false);
    notifyListeners();
  }

  /// Protège immédiatement l’interface quand l’application part en arrière-plan.
  void lock() {
    if (!_enabled || _authenticating || _locked) return;
    _locked = true;
    _lastResult = null;
    notifyListeners();
  }

  /// Réouvre l’interface après une authentification locale réussie.
  Future<BiometricAuthResult> unlock() {
    if (!_enabled) {
      return Future.value(
        const BiometricAuthResult(
          BiometricAuthStatus.authenticated,
          'Le verrou biométrique est désactivé.',
        ),
      );
    }
    return _authenticate();
  }

  Future<BiometricAuthResult> _authenticate() async {
    if (_authenticating) {
      return const BiometricAuthResult(
        BiometricAuthStatus.cancelled,
        'Vérification biométrique déjà en cours.',
      );
    }

    _authenticating = true;
    _lastResult = null;
    notifyListeners();
    try {
      final result = await _service.authenticate();
      _lastResult = result;
      if (result.isSuccess) _locked = false;
      return result;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }
}
