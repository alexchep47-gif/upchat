import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/message_model.dart';
import 'storage_service.dart';

/// Enveloppe versionnée échangée entre appareils et conservée dans l'outbox.
class OfflineMessageEnvelope {
  final String id;
  final String senderId;
  final String targetUserId;
  final String conversationId;
  final String type;
  final String content;
  final DateTime createdAt;
  final int ttl;

  const OfflineMessageEnvelope({
    required this.id,
    required this.senderId,
    required this.targetUserId,
    required this.conversationId,
    required this.type,
    required this.content,
    required this.createdAt,
    this.ttl = 4,
  });

  Map<String, dynamic> toMap() => {
        'protocol': 'upchat.offline.v1',
        'id': id,
        'senderId': senderId,
        'targetUserId': targetUserId,
        'conversationId': conversationId,
        'type': type,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'ttl': ttl,
      };

  String encode() => jsonEncode(toMap());

  static OfflineMessageEnvelope? fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final senderId = map['senderId'] as String?;
    final targetUserId = map['targetUserId'] as String?;
    final conversationId = map['conversationId'] as String?;
    if (id == null || senderId == null || targetUserId == null || conversationId == null) return null;
    return OfflineMessageEnvelope(
      id: id,
      senderId: senderId,
      targetUserId: targetUserId,
      conversationId: conversationId,
      type: map['type'] as String? ?? MessageType.text.name,
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      ttl: (map['ttl'] as num?)?.toInt() ?? 0,
    );
  }
}

/// File d'envoi durable : aucune perte lors d'une coupure ou d'une mise en
/// veille. Elle est vidée uniquement après ACK confirmé.
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();
  static const _prefix = 'outbox_v1_';
  final _uuid = const Uuid();

  Future<String> enqueue({
    String? messageId,
    required String targetUserId,
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final envelope = OfflineMessageEnvelope(
      id: messageId ?? _uuid.v4(),
      senderId: StorageService.userId,
      targetUserId: targetUserId,
      conversationId: conversationId,
      type: type.name,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    await StorageService.messages.put('$_prefix${envelope.id}', envelope.toMap());
    return envelope.id;
  }

  List<OfflineMessageEnvelope> pending() {
    return StorageService.messages.keys
        .where((key) => key.toString().startsWith(_prefix))
        .map((key) => StorageService.messages.get(key))
        .whereType<Map>()
        .map((map) => OfflineMessageEnvelope.fromMap(Map<String, dynamic>.from(map)))
        .whereType<OfflineMessageEnvelope>()
        .where((item) => item.ttl > 0)
        .toList();
  }

  Future<void> acknowledge(String id) => StorageService.messages.delete('$_prefix$id');

  Set<String> knownMessageIds() => StorageService.messages.keys
      .where((key) => !key.toString().startsWith('relay_'))
      .map((key) => key.toString())
      .toSet();
}
