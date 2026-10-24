import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

/// Service de stockage local (Hive + Secure Storage)
/// Gère le chiffrement AES des boîtes Hive
class StorageService {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static late Box _settingsBox;
  static late Box _usersBox;
  static late Box _conversationsBox;
  static late Box _messagesBox;
  static late Box _groupsBox;
  static late Box _storiesBox;
  static late Box _phoneDirectoryBox;

  /// Initialisation au démarrage de l'app
  static Future<void> init() async {
    // Récupère ou génère la clé de chiffrement
    String? encryptionKey =
        await _secureStorage.read(key: AppConstants.keyEncryptionKey);

    if (encryptionKey == null) {
      // Première installation → génère une clé AES 256 bits
      final key = base64Url.encode(List<int>.generate(
          32, (i) => DateTime.now().microsecondsSinceEpoch % 256 + i));
      await _secureStorage.write(
          key: AppConstants.keyEncryptionKey, value: key);
      encryptionKey = key;
    }

    final keyBytes = base64Url.decode(encryptionKey);

    // Ouvre les boîtes Hive (chiffrées pour les données sensibles)
    _settingsBox = await Hive.openBox('settings');
    _usersBox =
        await Hive.openBox('users', encryptionCipher: HiveAesCipher(keyBytes));
    _conversationsBox = await Hive.openBox('conversations',
        encryptionCipher: HiveAesCipher(keyBytes));
    _messagesBox = await Hive.openBox('messages',
        encryptionCipher: HiveAesCipher(keyBytes));
    _groupsBox =
        await Hive.openBox('groups', encryptionCipher: HiveAesCipher(keyBytes));
    _storiesBox = await Hive.openBox('stories',
        encryptionCipher: HiveAesCipher(keyBytes));
    _phoneDirectoryBox = await Hive.openBox('phone_directory',
        encryptionCipher: HiveAesCipher(keyBytes));

    // Crée un ID utilisateur local s'il n'existe pas
    if (_settingsBox.get(AppConstants.keyUserId) == null) {
      final userId = const Uuid().v4();
      await _settingsBox.put(AppConstants.keyUserId, userId);
    }
  }

  // ─── Getters des boîtes ───────────────────────────────────
  static Box get settings => _settingsBox;
  static Box get users => _usersBox;
  static Box get conversations => _conversationsBox;
  static Box get messages => _messagesBox;
  static Box get groups => _groupsBox;
  static Box get stories => _storiesBox;
  static Box get phoneDirectory => _phoneDirectoryBox;

  // ─── Helpers settings ─────────────────────────────────────
  static String get userId =>
      _settingsBox.get(AppConstants.keyUserId) as String;

  static String get userName =>
      _settingsBox.get(AppConstants.keyUserName, defaultValue: 'Utilisateur')
          as String;

  static Future<void> setUserName(String name) async {
    await _settingsBox.put(AppConstants.keyUserName, name);
  }

  static String? get userBio =>
      _settingsBox.get(AppConstants.keyUserBio) as String?;

  static Future<void> setUserBio(String? bio) async {
    await _settingsBox.put(AppConstants.keyUserBio, bio);
  }

  static String? get userPhotoPath =>
      _settingsBox.get(AppConstants.keyUserPhoto) as String?;

  static Future<void> setUserPhotoPath(String? path) async {
    await _settingsBox.put(AppConstants.keyUserPhoto, path);
  }

  /// Numéro de téléphone (digits, sans espaces) — utilisé pour le mode internet
  static String? get userPhone =>
      _settingsBox.get(AppConstants.keyUserPhone) as String?;

  static Future<void> setUserPhone(String? phone) async {
    final normalized = phone == null ? null : normalizePhone(phone);
    await _settingsBox.put(AppConstants.keyUserPhone, normalized);
  }

  /// Normalise un numéro : ne garde que les chiffres et le + initial
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return hasPlus ? '+$digits' : digits;
  }

  static bool get isOnboardingDone =>
      _settingsBox.get(AppConstants.keyOnboardingDone, defaultValue: false)
          as bool;

  static Future<void> setOnboardingDone() async {
    await _settingsBox.put(AppConstants.keyOnboardingDone, true);
  }

  /// Efface toutes les discussions (messages + conversations)
  static Future<void> clearChats() async {
    await _messagesBox.clear();
    await _conversationsBox.clear();
  }

  /// Ferme proprement les boîtes (appelé rarement)
  static Future<void> close() async {
    await Hive.close();
  }
}
