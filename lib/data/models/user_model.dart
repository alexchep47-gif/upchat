/// Modèle d'un utilisateur UpChat (local ou distant)
class UserModel {
  final String id;
  final String name;
  final String? bio;
  final String? photoPath;
  final String? endpointId; // ID Nearby Connections (si à proximité)
  final String? phoneNumber; // E.164 ou digits — mode internet
  final DateTime lastSeen;

  UserModel({
    required this.id,
    required this.name,
    this.bio,
    this.photoPath,
    this.endpointId,
    this.phoneNumber,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'photoPath': photoPath,
      'endpointId': endpointId,
      'phoneNumber': phoneNumber,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Inconnu',
      bio: map['bio'] as String?,
      photoPath: map['photoPath'] as String?,
      endpointId: map['endpointId'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      lastSeen: map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'] as String)
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? bio,
    String? photoPath,
    String? endpointId,
    String? phoneNumber,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoPath: photoPath ?? this.photoPath,
      endpointId: endpointId ?? this.endpointId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
