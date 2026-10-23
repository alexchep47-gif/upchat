import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';
import '../data/services/storage_service.dart';
import '../data/services/nearby_service.dart';

/// Gère les conversations et les messages (stockage Hive + envoi P2P)
class ChatProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final NearbyService _nearby = NearbyService();

  final List<ConversationModel> _conversations = [];
  final Map<String, List<MessageModel>> _messages = {};

  List<ConversationModel> get conversations => List.unmodifiable(_conversations);

  List<MessageModel> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  ChatProvider() {
    _loadFromStorage();
    // Écoute les messages entrants
    _nearby.onMessageReceived = _onIncomingMessage;
  }

  void _loadFromStorage() {
    // Charge les conversations
    for (final key in StorageService.conversations.keys) {
      final map = StorageService.conversations.get(key);
      if (map is Map) {
        _conversations.add(ConversationModel.fromMap(Map<String, dynamic>.from(map)));
      }
    }
    _conversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    // Charge les messages
    for (final key in StorageService.messages.keys) {
      final map = StorageService.messages.get(key);
      if (map is Map) {
        final msg = MessageModel.fromMap(Map<String, dynamic>.from(map));
        _messages.putIfAbsent(msg.conversationId, () => []);
        _messages[msg.conversationId]!.add(msg);
      }
    }

    // Trie les messages par date
    for (final list in _messages.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    notifyListeners();
  }

  /// Crée ou récupère une conversation 1-à-1
  ConversationModel getOrCreateConversation({
    required String peerId,
    required String peerName,
    String? endpointId,
  }) {
    final existing = _conversations.where((c) => c.id == peerId).toList();
    if (existing.isNotEmpty) return existing.first;

    final conv = ConversationModel(
      id: peerId,
      title: peerName,
      peerEndpointId: endpointId,
      participantIds: [StorageService.userId, peerId],
    );

    _conversations.insert(0, conv);
    StorageService.conversations.put(conv.id, conv.toMap());
    notifyListeners();
    return conv;
  }

  /// Envoie un message texte
  Future<void> sendTextMessage({
    required String conversationId,
    required String text,
    String? endpointId,
  }) async {
    final message = MessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: StorageService.userId,
      senderName: StorageService.userName,
      type: MessageType.text,
      content: text,
      isMe: true,
      status: MessageStatus.sending,
    );

    // Ajoute localement
    _messages.putIfAbsent(conversationId, () => []);
    _messages[conversationId]!.add(message);
    _updateConversationPreview(conversationId, text);
    notifyListeners();

    // Sauvegarde
    await StorageService.messages.put(message.id, message.toMap());

    // Envoi P2P si on a un endpoint
    bool success = false;
    if (endpointId != null) {
      success = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: text,
      );
    }

    // Met à jour le statut
    final index = _messages[conversationId]!.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      _messages[conversationId]![index] = message.copyWith(
        status: success ? MessageStatus.sent : MessageStatus.failed,
      );
      await StorageService.messages.put(
        message.id,
        _messages[conversationId]![index].toMap(),
      );
      notifyListeners();
    }
  }

  /// Message entrant (depuis NearbyService)
  void _onIncomingMessage(MessageModel message) {
    // Crée la conversation si besoin
    getOrCreateConversation(
      peerId: message.senderId,
      peerName: message.senderName,
    );

    _messages.putIfAbsent(message.conversationId, () => []);
    // Évite les doublons
    if (_messages[message.conversationId]!.any((m) => m.id == message.id)) return;

    _messages[message.conversationId]!.add(message);
    _updateConversationPreview(message.conversationId, message.content, isIncoming: true);

    StorageService.messages.put(message.id, message.toMap());
    notifyListeners();
  }

  void _updateConversationPreview(String conversationId, String text, {bool isIncoming = false}) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    final conv = _conversations[index];
    _conversations[index] = conv.copyWith(
      lastMessage: text,
      lastMessageAt: DateTime.now(),
      unreadCount: isIncoming ? conv.unreadCount + 1 : conv.unreadCount,
    );

    // Remonte en haut de la liste
    final updated = _conversations.removeAt(index);
    _conversations.insert(0, updated);

    StorageService.conversations.put(conversationId, updated.toMap());
  }

  /// Marque une conversation comme lue
  void markAsRead(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    StorageService.conversations.put(conversationId, _conversations[index].toMap());
    notifyListeners();
  }
}
