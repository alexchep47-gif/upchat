import 'package:flutter/material.dart';
import '../data/services/internet_service.dart';
import '../data/services/nearby_service.dart';

/// État global de connectivité : offline local + mode internet optionnel
class ConnectivityProvider extends ChangeNotifier {
  final InternetService _internet = InternetService();
  final NearbyService _nearby = NearbyService();

  bool _internetModeEnabled = false;
  bool _isOnline = false;

  bool get internetModeEnabled => _internetModeEnabled;
  bool get isOnline => _isOnline;
  bool get isHybridReady => _internetModeEnabled && _isOnline;

  /// Mode actuel affiché à l'utilisateur
  String get statusLabel {
    if (_internetModeEnabled && _isOnline) {
      return 'Mode hybride (local + internet)';
    }
    if (_internetModeEnabled && !_isOnline) {
      return 'Mode internet activé — en attente de réseau';
    }
    if (_nearby.isDiscovering || _nearby.isAdvertising) {
      return 'Mode offline (Bluetooth / WiFi Direct)';
    }
    return 'Hors ligne';
  }

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    await _internet.loadPreference();
    _internetModeEnabled = _internet.isEnabled;
    _isOnline = _internet.isOnline;

    _internet.onConnectivityChanged = (online) {
      _isOnline = online;
      notifyListeners();
    };

    notifyListeners();
  }

  Future<void> setInternetMode(bool enabled) async {
    await _internet.setEnabled(enabled);
    _internetModeEnabled = enabled;
    _isOnline = _internet.isOnline;
    notifyListeners();
  }
}
