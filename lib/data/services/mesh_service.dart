import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import 'nearby_service.dart';
import 'storage_service.dart';

/// Service de relais mesh (1 hop)
/// Si le destinataire n'est pas directement connecté, on demande aux
/// voisins de retransmettre le message quand ils le rencontrent.
class MeshService {
  static final MeshService _instance = MeshService._internal();
  factory MeshService() => _instance;
  MeshService._internal();

  final NearbyService _nearby = NearbyService();
  final Uuid _uuid = const Uuid();

  // Messages en attente de relais : messageId → payload
  final Map<String, Map<String, dynamic>> _pendingRelay = {};

  // IDs déjà vus (anti-boucle)
  final Set<String> _seenMessageIds = {};

  static const int maxHops = 2; // 1 hop = voisin direct, 2 = voisin du voisin

  /// Envoie un message avec relais mesh si nécessaire
  Future<bool> sendWithMesh({
    required String targetUserId,
    required String conversationId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaPath,
  }) async {
    final messageId = _uuid.v4();

    // 1. Destinataire directement connecté ?
    String? directEndpoint;
    for (final entry in _nearby.connectedEndpoints.entries) {
      if (entry.value == targetUserId) {
        directEndpoint = entry.key;
        break;
      }
    }

    if (directEndpoint != null) {
      // Envoi direct
      if (mediaPath != null && type != MessageType.text) {
        return await _nearby.sendFile(
          endpointId: directEndpoint,
          conversationId: conversationId,
          filePath: mediaPath,
          mediaType: type,
        );
      }
      return await _nearby.sendTextMessage(
        endpointId: directEndpoint,
        conversationId: conversationId,
        text: text,
      );
    }

    // 2. Pas de connexion directe → relais via tous les voisins
    final relayPayload = {
      'type': 'mesh_relay',
      'messageId': messageId,
      'targetUserId': targetUserId,
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'messageType': type.name,
      'content': text,
      'hop': 1,
      'maxHops': maxHops,
      'createdAt': DateTime.now().toIso8601String(),
    };

    _pendingRelay[messageId] = relayPayload;
    _seenMessageIds.add(messageId);

    // Stocke localement pour retransmettre plus tard si besoin
    await StorageService.messages.put('relay_$messageId', relayPayload);

    bool anySent = false;
    for (final endpointId in _nearby.connectedEndpoints.keys) {
      final ok = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: 'mesh_relay',
        text: jsonEncode(relayPayload),
      );
      if (ok) anySent = true;
    }

    debugPrint('Mesh: message $messageId mis en relais (direct=false, sent=$anySent)');
    return anySent;
  }

  /// Traite un payload de relais reçu
  void handleRelayPayload(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    if (messageId == null || _seenMessageIds.contains(messageId)) return;

    _seenMessageIds.add(messageId);

    final targetUserId = payload['targetUserId'] as String?;
    final hop = (payload['hop'] as int? ?? 1) + 1;
    final maxHops = payload['maxHops'] as int? ?? MeshService.maxHops;

    // Est-ce pour moi ?
    if (targetUserId == StorageService.userId) {
      // Message destiné à moi → créer le message local
      final message = MessageModel(
        id: messageId,
        conversationId: payload['conversationId'] as String? ?? payload['senderId'] as String? ?? '',
        senderId: payload['senderId'] as String? ?? '',
        senderName: payload['senderName'] as String? ?? 'Inconnu',
        type: MessageType.values.firstWhere(
          (e) => e.name == payload['messageType'],
          orElse: () => MessageType.text,
        ),
        content: payload['content'] as String? ?? '',
        isMe: false,
        status: MessageStatus.delivered,
      );

      // Notifie via NearbyService callback (réutilise le même canal)
      NearbyService().onMessageReceived?.call(message);
      debugPrint('Mesh: message $messageId reçu pour moi');
      return;
    }

    // Sinon, on relaie si on n'a pas dépassé le max hops
    if (hop <= maxHops) {
      final nextPayload = Map<String, dynamic>.from(payload);
      nextPayload['hop'] = hop;

      for (final endpointId in _nearby.connectedEndpoints.keys) {
        // Ne pas renvoyer à l'émetteur original si possible
        _nearby.sendTextMessage(
          endpointId: endpointId,
          conversationId: 'mesh_relay',
          text: jsonEncode(nextPayload),
        );
      }
      debugPrint('Mesh: relais hop $hop pour $messageId');
    }
  }

  /// Quand un nouvel appareil se connecte, on essaie de livrer les messages en attente
  Future<void> onNewConnection(String endpointId, String userId) async {
    final toRemove = <String>[];

    for (final entry in _pendingRelay.entries) {
      final payload = entry.value;
      if (payload['targetUserId'] == userId) {
        await _nearby.sendTextMessage(
          endpointId: endpointId,
          conversationId: payload['conversationId'] as String? ?? '',
          text: payload['content'] as String? ?? '',
        );
        toRemove.add(entry.key);
        debugPrint('Mesh: livraison différée de ${entry.key} à $userId');
      }
    }

    for (final id in toRemove) {
      _pendingRelay.remove(id);
      await StorageService.messages.delete('relay_$id');
    }
  }
}
