import '../models/user_model.dart';
import 'storage_service.dart';

/// Index local des utilisateurs dont le numéro est enregistré dans UpChat.
/// La couche de transport peut être remplacée par la signalisation WebSocket
/// sans modifier l'interface utilisateur.
class ContactDirectoryService {
  static const int minimumPhoneDigits = 6;
  static final ContactDirectoryService instance = ContactDirectoryService._();

  ContactDirectoryService._();

  List<UserModel> searchByPhone(String query, {String? excludingUserId}) {
    final normalized = UserModel.normalizePhone(query);
    if (_digitsOnly(normalized).length < minimumPhoneDigits) return const [];

    return StorageService.users.values
        .whereType<Map>()
        .map((value) => UserModel.fromMap(Map<String, dynamic>.from(value)))
        .where((user) => user.id != excludingUserId)
        .where((user) => _matches(user.phoneNumber, normalized))
        .toList(growable: false);
  }

  UserModel? findByPhone(String phoneNumber, {String? excludingUserId}) {
    final matches = searchByPhone(phoneNumber, excludingUserId: excludingUserId);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> upsert(UserModel user) async {
    if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      await remove(user.id);
      return;
    }
    await StorageService.users.put(user.id, user.toMap());
  }

  Future<void> remove(String userId) async {
    await StorageService.users.delete(userId);
  }

  bool _matches(String? stored, String query) {
    if (stored == null) return false;
    return _digitsOnly(stored) == _digitsOnly(query);
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}
