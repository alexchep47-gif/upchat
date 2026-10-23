/// Modèle d'une conversation (1-à-1 ou groupe)
class ConversationModel {
  final String id;
  final String title; // nom du contact ou du groupe
  final String? photoPath;
  final bool isGroup;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? peerEndpointId; // pour les 1-à-1

  ConversationModel({
    required this.id,
    required this.title,
    this.photoPath,
    this.isGroup = false,
    this.participantIds = const [],
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.peerEndpointId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'photoPath': photoPath,
      'isGroup': isGroup,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'unreadCount': unreadCount,
      'peerEndpointId': peerEndpointId,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    return ConversationModel(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Discussion',
      photoPath: map['photoPath'] as String?,
      isGroup: map['isGroup'] as bool? ?? false,
      participantIds: (map['participantIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lastMessage: map['lastMessage'] as String?,
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.parse(map['lastMessageAt'] as String)
          : null,
      unreadCount: map['unreadCount'] as int? ?? 0,
      peerEndpointId: map['peerEndpointId'] as String?,
    );
  }

  ConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? photoPath,
  }) {
    return ConversationModel(
      id: id,
      title: title,
      photoPath: photoPath ?? this.photoPath,
      isGroup: isGroup,
      participantIds: participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      peerEndpointId: peerEndpointId,
    );
  }
}
