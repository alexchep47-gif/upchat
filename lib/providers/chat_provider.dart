import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';
import '../data/services/storage_service.dart';
import '../data/services/nearby_service.dart';
import '../data/services/mesh_service.dart';
import '../data/services/internet_service.dart';
import '../data/services/phone_directory_service.dart';
import '../data/services/offline_sync_service.dart';

class ChatProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final NearbyService _nearby = NearbyService();
  final MeshService _mesh = MeshService();
  final InternetService _internet = InternetService();
  final PhoneDirectoryService _phoneDir = PhoneDirectoryService();
  final OfflineSyncService _offline = OfflineSyncService.instance;

  final List<ConversationModel> _conversations = [];
  final Map<String, List<MessageModel>> _messages = {};
  final Map<String, bool> _typingUsers = {};

  List<ConversationModel> get conversations =>
      List.unmodifiable(_conversations);
  bool isTyping(String userId) => _typingUsers[userId] ?? false;

  List<MessageModel> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  ChatProvider() {
    _loadFromStorage();
    _nearby.onMessageReceived = _onIncomingMessage;
    _nearby.onStatusUpdate = _onStatusUpdate;
    _nearby.onTyping = (userId, typing) {
      _typingUsers[userId] = typing;
      notifyListeners();
    };
    _nearby.onConnected = (endpointId, userId) {
      _mesh.onNewConnection(endpointId, userId);
      _flushOfflineMessages(endpointId, userId);
    };
    _internet.onMessageReceived = _onIncomingMessage;
    // Charge le mode internet au démarrage
    _internet.loadPreference();
  }

  Future<void> _flushOfflineMessages(String endpointId, String userId) async {
    for (final pending in _offline.pending()) {
      if (pending.targetUserId != userId) continue;
      final sent = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: pending.conversationId,
        text: pending.content,
      );
      if (sent) await _offline.acknowledge(pending.id);
    }
  }

  void _loadFromStorage() {
    for (final key in StorageService.conversations.keys) {
      final map = StorageService.conversations.get(key);
      if (map is Map) {
        _conversations
            .add(ConversationModel.fromMap(Map<String, dynamic>.from(map)));
      }
    }
    _conversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime(2000);
      final bTime = b.lastMessageAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    for (final key in StorageService.messages.keys) {
      if (key.toString().startsWith('relay_') ||
          key.toString().startsWith('outbox_')) continue;
      final map = StorageService.messages.get(key);
      if (map is Map) {
        try {
          final msg = MessageModel.fromMap(Map<String, dynamic>.from(map));
          _messages.putIfAbsent(msg.conversationId, () => []);
          _messages[msg.conversationId]!.add(msg);
        } catch (_) {}
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
    await _offline.enqueue(
      messageId: message.id,
      targetUserId: conversationId,
      conversationId: conversationId,
      content: text,
    );

    bool success = false;

    if (endpointId != null) {
      success = await _nearby.sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: text,
      );
    }

    if (!success) {
      success = await _mesh.sendWithMesh(
        targetUserId: conversationId,
        conversationId: conversationId,
        text: text,
      );
    }

    // Internet : tente toujours si contact téléphone connu ou mode activé
    if (!success) {
      final known = _phoneDir.all().where((u) => u.id == conversationId);
      final phone = known.isNotEmpty ? known.first.phoneNumber : null;
      final shouldTryNet = _internet.isEnabled || (phone != null && phone.isNotEmpty);
      if (shouldTryNet) {
        if (!_internet.isEnabled) {
          await _internet.setEnabled(true);
        }
        success = await _internet.sendMessage(
          targetUserId: conversationId,
          conversationId: conversationId,
          text: text,
          targetPhone: phone,
        );
      }
    }

    _updateMessageStatus(
        message.id, success ? MessageStatus.sent : MessageStatus.failed);
    if (success) await _offline.acknowledge(message.id);
  }

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
            : type == MessageType.audio
                ? '🎤 Note vocale'
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
    await _offline.enqueue(
      messageId: message.id,
      targetUserId: conversationId,
      conversationId: conversationId,
      content: preview,
      type: type,
    );

    bool success = false;
    if (endpointId != null) {
      success = await _nearby.sendFile(
        endpointId: endpointId,
        conversationId: conversationId,
        filePath: mediaPath,
        mediaType: type,
      );
    }
    if (!success) {
      success = await _mesh.sendWithMesh(
        targetUserId: conversationId,
        conversationId: conversationId,
        text: preview,
        type: type,
        mediaPath: mediaPath,
      );
    }
    if (!success) {
      final known = _phoneDir.all().where((u) => u.id == conversationId);
      final phone = known.isNotEmpty ? known.first.phoneNumber : null;
      if (_internet.isEnabled || (phone != null && phone.isNotEmpty)) {
        if (!_internet.isEnabled) await _internet.setEnabled(true);
        success = await _internet.sendMessage(
          targetUserId: conversationId,
          conversationId: conversationId,
          text: preview,
          type: type,
          mediaPath: mediaPath,
          targetPhone: phone,
        );
      }
    }

    _updateMessageStatus(
        message.id, success ? MessageStatus.sent : MessageStatus.failed);
    if (success) await _offline.acknowledge(message.id);
  }

  void _addLocalMessage(MessageModel message, {required String preview}) {
    _messages.putIfAbsent(message.conversationId, () => []);
    _messages[message.conversationId]!.add(message);
    _updateConversationPreview(message.conversationId, preview);
    StorageService.messages.put(message.id, message.toMap());
    notifyListeners();
  }

  void _updateMessageStatus(String messageId, MessageStatus status) {
    for (final list in _messages.values) {
      final index = list.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final current = list[index].status;
        if (_statusRank(status) >= _statusRank(current)) {
          list[index] = list[index].copyWith(status: status);
          StorageService.messages.put(messageId, list[index].toMap());
          notifyListeners();
        }
        return;
      }
    }
  }

  int _statusRank(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return 0;
      case MessageStatus.failed:
        return 0;
      case MessageStatus.sent:
        return 1;
      case MessageStatus.delivered:
        return 2;
      case MessageStatus.read:
        return 3;
    }
  }

  void _onStatusUpdate(String messageId, MessageStatus status) {
    _updateMessageStatus(messageId, status);
    if (status == MessageStatus.delivered || status == MessageStatus.read) {
      _offline.acknowledge(messageId);
    }
  }

  void _onIncomingMessage(MessageModel message) {
    if (message.content.startsWith('{') &&
        message.content.contains('mesh_relay')) {
      try {
        final map = jsonDecode(message.content) as Map<String, dynamic>;
        if (map['type'] == 'mesh_relay') {
          _mesh.handleRelayPayload(map);
          return;
        }
      } catch (_) {}
    }

    // Chez le destinataire, la conversation = id de l’expéditeur
    // (pas le conversationId envoyé par l’émetteur, qui est souvent notre propre id).
    final peerId = message.isMe ? message.conversationId : message.senderId;
    final normalized = message.copyWith(conversationId: peerId);

    getOrCreateConversation(
      peerId: peerId,
      peerName: normalized.senderName,
    );

    _messages.putIfAbsent(peerId, () => []);
    if (_messages[peerId]!.any((m) => m.id == normalized.id)) return;

    _messages[peerId]!.add(normalized);
    _updateConversationPreview(peerId, normalized.content, isIncoming: true);
    StorageService.messages.put(normalized.id, normalized.toMap());
    notifyListeners();
  }

  void _updateConversationPreview(String conversationId, String text,
      {bool isIncoming = false}) {
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

  void markAsRead(String conversationId, {String? endpointId}) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
      StorageService.conversations
          .put(conversationId, _conversations[index].toMap());
    }

    final msgs = _messages[conversationId] ?? [];
    final unreadIds = msgs
        .where((m) => !m.isMe && m.status != MessageStatus.read)
        .map((m) => m.id)
        .toList();

    if (endpointId != null && unreadIds.isNotEmpty) {
      _nearby.sendReadReceipts(endpointId, unreadIds);
      for (final id in unreadIds) {
        _updateMessageStatus(id, MessageStatus.read);
      }
    }

    notifyListeners();
  }

  Future<void> clearConversationMessages(String conversationId) async {
    final messages = _messages.remove(conversationId) ?? [];
    for (final message in messages) {
      await StorageService.messages.delete(message.id);
    }

    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conversation = _conversations[index];
      final cleared = ConversationModel(
        id: conversation.id,
        title: conversation.title,
        photoPath: conversation.photoPath,
        isGroup: conversation.isGroup,
        participantIds: conversation.participantIds,
        peerEndpointId: conversation.peerEndpointId,
      );
      _conversations[index] = cleared;
      await StorageService.conversations.put(conversationId, cleared.toMap());
    }
    notifyListeners();
  }

  void sendTyping(String endpointId, bool isTyping) {
    _nearby.sendTyping(endpointId, isTyping);
  }
}
