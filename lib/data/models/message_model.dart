/// Types de messages supportés
enum MessageType { text, image, video, audio, file, system }

/// Statut d'un message
enum MessageStatus { sending, sent, delivered, read, failed }

/// Modèle d'un message
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content; // texte ou chemin local du média
  final String? mediaPath;
  final int? mediaSize; // en octets
  final MessageStatus status;
  final DateTime createdAt;
  final bool isMe;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.mediaPath,
    this.mediaSize,
    this.status = MessageStatus.sending,
    DateTime? createdAt,
    this.isMe = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'mediaPath': mediaPath,
      'mediaSize': mediaSize,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'isMe': isMe,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversationId'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'] as String? ?? '',
      mediaPath: map['mediaPath'] as String?,
      mediaSize: map['mediaSize'] as int?,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      isMe: map['isMe'] as bool? ?? false,
    );
  }

  MessageModel copyWith({
    MessageStatus? status,
    String? mediaPath,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaSize: mediaSize,
      status: status ?? this.status,
      createdAt: createdAt,
      isMe: isMe,
    );
  }
}
