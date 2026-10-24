import '../models/user_model.dart';
import 'storage_service.dart';

/// Cache local des contacts découverts / ajoutés par numéro de téléphone.
/// Clé Hive = numéro normalisé, valeur = UserModel sérialisé.
class PhoneDirectoryService {
  static final PhoneDirectoryService _instance =
      PhoneDirectoryService._internal();
  factory PhoneDirectoryService() => _instance;
  PhoneDirectoryService._internal();

  /// Enregistre ou met à jour un contact téléphone
  Future<void> upsert(UserModel user) async {
    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) return;
    final key = StorageService.normalizePhone(phone);
    if (key.isEmpty) return;
    await StorageService.phoneDirectory.put(key, user.toMap());
  }

  /// Recherche locale par numéro
  UserModel? findLocal(String phone) {
    final key = StorageService.normalizePhone(phone);
    if (key.isEmpty) return null;
    final map = StorageService.phoneDirectory.get(key);
    if (map is Map) {
      return UserModel.fromMap(Map<String, dynamic>.from(map));
    }
    return null;
  }

  /// Tous les contacts téléphone connus
  List<UserModel> all() {
    final list = <UserModel>[];
    for (final key in StorageService.phoneDirectory.keys) {
      final map = StorageService.phoneDirectory.get(key);
      if (map is Map) {
        try {
          list.add(UserModel.fromMap(Map<String, dynamic>.from(map)));
        } catch (_) {}
      }
    }
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> remove(String phone) async {
    final key = StorageService.normalizePhone(phone);
    if (key.isEmpty) return;
    await StorageService.phoneDirectory.delete(key);
  }
}
