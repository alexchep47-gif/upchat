/// Modèle d'un groupe offline
class GroupModel {
  final String id;
  final String name;
  final String? photoPath;
  final String createdBy;
  final List<String> memberIds;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.photoPath,
    required this.createdBy,
    this.memberIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'photoPath': photoPath,
      'createdBy': createdBy,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Groupe',
      photoPath: map['photoPath'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      memberIds: (map['memberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
