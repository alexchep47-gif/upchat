import '../models/user_model.dart';
import 'storage_service.dart';

/// Index local des utilisateurs dont le numéro est enregistré dans UpChat.
/// La couche de transport peut être remplacée par la signalisation WebSocket
/// sans modifier l'interface utilisateur.
class ContactDirectoryService {
  List<UserModel> searchByPhone(String query) {
    final normalized = UserModel.normalizePhone(query);
    if (normalized.length < 6) return const [];

    return StorageService.users.values
        .whereType<Map>()
        .map((value) => UserModel.fromMap(Map<String, dynamic>.from(value)))
        .where((user) => user.phoneNumber == normalized)
        .toList(growable: false);
  }

  UserModel? findByPhone(String phoneNumber) {
    final matches = searchByPhone(phoneNumber);
    return matches.isEmpty ? null : matches.first;
  }
}
