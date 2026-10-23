import 'package:flutter/material.dart';

/// État de la découverte et des connexions P2P
/// (implémentation complète de Nearby Connections à venir)
class NearbyProvider extends ChangeNotifier {
  bool _isDiscovering = false;
  bool _isAdvertising = false;
  final List<Map<String, dynamic>> _nearbyDevices = [];
  final Map<String, String> _connectedEndpoints = {}; // endpointId → userId

  bool get isDiscovering => _isDiscovering;
  bool get isAdvertising => _isAdvertising;
  List<Map<String, dynamic>> get nearbyDevices => List.unmodifiable(_nearbyDevices);
  Map<String, String> get connectedEndpoints => Map.unmodifiable(_connectedEndpoints);

  bool get hasNearbyDevices => _nearbyDevices.isNotEmpty;

  /// Démarre la découverte + publicité
  Future<void> start() async {
    // TODO: implémenter Nearby Connections
    _isDiscovering = true;
    _isAdvertising = true;
    notifyListeners();
  }

  /// Arrête tout
  Future<void> stop() async {
    _isDiscovering = false;
    _isAdvertising = false;
    _nearbyDevices.clear();
    notifyListeners();
  }

  void addDevice(Map<String, dynamic> device) {
    final exists = _nearbyDevices.any((d) => d['endpointId'] == device['endpointId']);
    if (!exists) {
      _nearbyDevices.add(device);
      notifyListeners();
    }
  }

  void removeDevice(String endpointId) {
    _nearbyDevices.removeWhere((d) => d['endpointId'] == endpointId);
    _connectedEndpoints.remove(endpointId);
    notifyListeners();
  }
}
