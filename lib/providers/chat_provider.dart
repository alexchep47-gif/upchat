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
    _nearby.onMessageReceived = _onIncomingMessage;
  }

  void _loadFromStorage() {
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

    for (final key in StorageService.messages.keys) {
      final map = StorageService.messages.get(key);
      if (map is Map) {
        final msg = MessageModel.fromMap(Map<String, dynamic>.from(map));
        _messages.putIfAbsent(msg.conversationId, () => []);
        _messages[msg.conversationId]!.add(msg);
      }
    }

    for (final list in _messages.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    notifyListeners();
  }

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

    _addLocalMessage(message, preview: text);

    bool success = false;
    if (endpointId != null) {
      success = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: text,
      );
    }

    _updateMessageStatus(message, success ? MessageStatus.sent : MessageStatus.failed);
  }

  /// Envoie un média (image / vidéo)
  Future<void> sendMediaMessage({
    required String conversationId,
    required String mediaPath,
    required MessageType type,
    String? endpointId,
  }) async {
    final preview = type == MessageType.image
        ? '📷 Photo'
        : type == MessageType.video
            ? '🎬 Vidéo'
            : '📎 Fichier';

    final message = MessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: StorageService.userId,
      senderName: StorageService.userName,
      type: type,
      content: preview,
      mediaPath: mediaPath,
      isMe: true,
      status: MessageStatus.sending,
    );

    _addLocalMessage(message, preview: preview);

    // Pour l'instant on envoie juste le texte de preview via P2P
    // (transfert de fichiers binaires à améliorer en v2)
    bool success = false;
    if (endpointId != null) {
      success = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: preview,
      );
    }

    _updateMessageStatus(message, success ? MessageStatus.sent : MessageStatus.failed);
  }

  void _addLocalMessage(MessageModel message, {required String preview}) {
    _messages.putIfAbsent(message.conversationId, () => []);
    _messages[message.conversationId]!.add(message);
    _updateConversationPreview(message.conversationId, preview);
    StorageService.messages.put(message.id, message.toMap());
    notifyListeners();
  }

  void _updateMessageStatus(MessageModel message, MessageStatus status) {
    final list = _messages[message.conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    list[index] = message.copyWith(status: status);
    StorageService.messages.put(message.id, list[index].toMap());
    notifyListeners();
  }

  void _onIncomingMessage(MessageModel message) {
    getOrCreateConversation(
      peerId: message.senderId,
      peerName: message.senderName,
    );

    _messages.putIfAbsent(message.conversationId, () => []);
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

    final updated = _conversations.removeAt(index);
    _conversations.insert(0, updated);
    StorageService.conversations.put(conversationId, updated.toMap());
  }

  void markAsRead(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    StorageService.conversations.put(conversationId, _conversations[index].toMap());
    notifyListeners();
  }
}
