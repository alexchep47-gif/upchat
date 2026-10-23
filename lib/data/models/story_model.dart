/// Type de story
enum StoryType { text, image, video }

/// Modèle d'une story offline (expire après 24h)
class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final StoryType type;
  final String content; // texte ou chemin média
  final String? mediaPath;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy; // IDs des utilisateurs qui ont vu

  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.content,
    this.mediaPath,
    DateTime? createdAt,
    DateTime? expiresAt,
    this.viewedBy = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'content': content,
      'mediaPath': mediaPath,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'viewedBy': viewedBy,
    };
  }

  factory StoryModel.fromMap(Map<String, dynamic> map) {
    return StoryModel(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String? ?? '',
      type: StoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StoryType.text,
      ),
      content: map['content'] as String? ?? '',
      mediaPath: map['mediaPath'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : DateTime.now().add(const Duration(hours: 24)),
      viewedBy: (map['viewedBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
