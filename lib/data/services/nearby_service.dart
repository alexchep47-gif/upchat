import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Service central P2P utilisant Nearby Connections (Bluetooth + WiFi Direct)
/// Gère : découverte, connexion, envoi/réception de messages et médias
class NearbyService {
  static final NearbyService _instance = NearbyService._internal();
  factory NearbyService() => _instance;
  NearbyService._internal();

  final Nearby _nearby = Nearby();
  final Uuid _uuid = const Uuid();

  bool _isAdvertising = false;
  bool _isDiscovering = false;

  // endpointId → UserModel
  final Map<String, UserModel> _discovered = {};
  // endpointId → userId
  final Map<String, String> _connected = {};

  // Callbacks pour l'UI
  Function(List<UserModel>)? onDevicesChanged;
  Function(MessageModel)? onMessageReceived;
  Function(String endpointId, String userId)? onConnected;
  Function(String endpointId)? onDisconnected;

  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  List<UserModel> get discoveredDevices => _discovered.values.toList();
  Map<String, String> get connectedEndpoints => Map.unmodifiable(_connected);

  /// Démarre publicité + découverte
  Future<void> start() async {
    final userId = StorageService.userId;
    final userName = StorageService.userName;

    // Payload d'identification (envoyé à la connexion)
    final userInfo = jsonEncode({
      'userId': userId,
      'name': userName,
      'bio': StorageService.userBio,
    });

    try {
      // 1. Publicité (se rendre visible)
      _isAdvertising = await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: AppConstants.serviceId,
      );

      // 2. Découverte des autres
      _isDiscovering = await _nearby.startDiscovery(
        userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('Appareil trouvé: $endpointName ($endpointId)');
          _discovered[endpointId] = UserModel(
            id: endpointId, // temporaire jusqu'à connexion
            name: endpointName,
            endpointId: endpointId,
          );
          onDevicesChanged?.call(discoveredDevices);

          // Demande automatique de connexion
          _requestConnection(endpointId, userName, userInfo);
        },
        onEndpointLost: (endpointId) {
          debugPrint('Appareil perdu: $endpointId');
          _discovered.remove(endpointId);
          onDevicesChanged?.call(discoveredDevices);
        },
        serviceId: AppConstants.serviceId,
      );
    } catch (e) {
      debugPrint('Erreur Nearby start: $e');
      _isAdvertising = false;
      _isDiscovering = false;
    }
  }

  /// Arrête tout
  Future<void> stop() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    _isAdvertising = false;
    _isDiscovering = false;
    _discovered.clear();
    _connected.clear();
    onDevicesChanged?.call([]);
  }

  /// Demande de connexion à un endpoint
  Future<void> _requestConnection(
    String endpointId,
    String userName,
    String userInfo,
  ) async {
    try {
      await _nearby.requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('Erreur requestConnection: $e');
    }
  }

  /// Connexion initiée → on accepte automatiquement
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    debugPrint('Connexion initiée avec ${info.endpointName}');
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: (endpointId, transferUpdate) {
        // Utile pour les gros médias (progression)
        if (transferUpdate.status == PayloadStatus.SUCCESS) {
          debugPrint('Transfert terminé vers $endpointId');
        }
      },
    );
  }

  /// Résultat de la connexion
  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      debugPrint('Connecté à $endpointId');
      // On enverra l'identité juste après
      _sendIdentity(endpointId);
    } else {
      debugPrint('Échec connexion $endpointId: $status');
    }
  }

  /// Déconnexion
  void _onDisconnected(String endpointId) {
    debugPrint('Déconnecté de $endpointId');
    _connected.remove(endpointId);
    onDisconnected?.call(endpointId);
  }

  /// Envoie notre identité juste après connexion
  Future<void> _sendIdentity(String endpointId) async {
    final payload = jsonEncode({
      'type': 'identity',
      'userId': StorageService.userId,
      'name': StorageService.userName,
      'bio': StorageService.userBio,
    });
    await _nearby.sendBytesPayload(
      endpointId,
      Uint8List.fromList(utf8.encode(payload)),
    );
  }

  /// Réception d'un payload (message ou identité)
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES) return;

    try {
      final data = utf8.decode(payload.bytes!);
      final map = jsonDecode(data) as Map<String, dynamic>;

      final type = map['type'] as String?;

      if (type == 'identity') {
        final userId = map['userId'] as String;
        final name = map['name'] as String? ?? 'Inconnu';

        _connected[endpointId] = userId;
        _discovered[endpointId] = UserModel(
          id: userId,
          name: name,
          bio: map['bio'] as String?,
          endpointId: endpointId,
        );

        onConnected?.call(endpointId, userId);
        onDevicesChanged?.call(discoveredDevices);
        return;
      }

      if (type == 'message') {
        final message = MessageModel(
          id: map['id'] as String? ?? _uuid.v4(),
          conversationId: map['conversationId'] as String? ?? endpointId,
          senderId: map['senderId'] as String? ?? endpointId,
          senderName: map['senderName'] as String? ?? 'Inconnu',
          type: MessageType.values.firstWhere(
            (e) => e.name == map['messageType'],
            orElse: () => MessageType.text,
          ),
          content: map['content'] as String? ?? '',
          isMe: false,
          status: MessageStatus.delivered,
        );

        onMessageReceived?.call(message);
      }
    } catch (e) {
      debugPrint('Erreur parsing payload: $e');
    }
  }

  /// Envoie un message texte à un endpoint
  Future<bool> sendTextMessage({
    required String endpointId,
    required String conversationId,
    required String text,
  }) async {
    final messageId = _uuid.v4();
    final payload = jsonEncode({
      'type': 'message',
      'id': messageId,
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'messageType': MessageType.text.name,
      'content': text,
    });

    try {
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(payload)),
      );
      return true;
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      return false;
    }
  }

  /// Envoie un message à tous les endpoints connectés (pour les groupes)
  Future<void> broadcastText({
    required String conversationId,
    required String text,
  }) async {
    for (final endpointId in _connected.keys) {
      await sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: text,
      );
    }
  }
}
