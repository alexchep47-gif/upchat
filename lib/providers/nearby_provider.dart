import 'package:flutter/material.dart';
import '../data/models/user_model.dart';
import '../data/models/message_model.dart';
import '../data/services/nearby_service.dart';

/// Bridge entre NearbyService et l'UI (Provider)
class NearbyProvider extends ChangeNotifier {
  final NearbyService _service = NearbyService();

  bool _isRunning = false;
  List<UserModel> _devices = [];
  final Map<String, String> _connected = {}; // endpointId → userId

  bool get isRunning => _isRunning;
  bool get isDiscovering => _service.isDiscovering;
  bool get isAdvertising => _service.isAdvertising;
  List<UserModel> get nearbyDevices => List.unmodifiable(_devices);
  Map<String, String> get connectedEndpoints => Map.unmodifiable(_connected);
  bool get hasNearbyDevices => _devices.isNotEmpty;

  NearbyProvider() {
    _service.onDevicesChanged = (devices) {
      _devices = devices;
      notifyListeners();
    };
    _service.onConnected = (endpointId, userId) {
      _connected[endpointId] = userId;
      notifyListeners();
    };
    _service.onDisconnected = (endpointId) {
      _connected.remove(endpointId);
      notifyListeners();
    };
  }

  /// Démarre la découverte + publicité
  Future<void> start() async {
    if (_isRunning) return;
    await _service.start();
    _isRunning = true;
    notifyListeners();
  }

  /// Arrête tout
  Future<void> stop() async {
    await _service.stop();
    _isRunning = false;
    _devices = [];
    _connected.clear();
    notifyListeners();
  }

  /// Envoie un message texte
  Future<bool> sendText({
    required String endpointId,
    required String conversationId,
    required String text,
  }) {
    return _service.sendTextMessage(
      endpointId: endpointId,
      conversationId: conversationId,
      text: text,
    );
  }

  /// Callback pour les messages reçus (à brancher depuis ChatProvider)
  void setOnMessageReceived(Function(MessageModel) callback) {
    _service.onMessageReceived = callback;
  }
}
