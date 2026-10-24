/// Type de story
enum StoryType { text, image, video }

class StoryComment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  StoryComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StoryComment.fromMap(Map<String, dynamic> map) {
    return StoryComment(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'Utilisateur',
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

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
  final List<StoryComment> comments;

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
    this.comments = const [],
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
      'comments': comments.map((comment) => comment.toMap()).toList(),
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
      comments: (map['comments'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => StoryComment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}
