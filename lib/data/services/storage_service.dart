import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  static late Box _secureSettingsBox;
  static late Box _usersBox;
  static late Box _conversationsBox;
  static late Box _messagesBox;
  static late Box _groupsBox;
  static late Box _storiesBox;
  static late Box _phoneDirectoryBox;

  static String _boxName(String name) => kIsWeb ? '${name}_web' : name;

  /// Initialisation au démarrage de l'app
  static Future<void> init() async {
    // flutter_secure_storage peut attendre indéfiniment dans certains
    // navigateurs. Le Web utilise une boîte Hive locale pour conserver la
    // clé de chiffrement, tandis qu'Android/iOS gardent le stockage natif.
    if (kIsWeb) {
      _settingsBox = await Hive.openBox(_boxName('settings'));
    }

    // Récupère ou génère la clé de chiffrement
    String? encryptionKey = kIsWeb
        ? _settingsBox.get(AppConstants.keyEncryptionKey) as String?
        : await _secureStorage.read(key: AppConstants.keyEncryptionKey);

    if (encryptionKey == null) {
      // Première installation → génère une clé AES 256 bits
      final key = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      if (kIsWeb) {
        await _settingsBox.put(AppConstants.keyEncryptionKey, key);
      } else {
        await _secureStorage.write(
            key: AppConstants.keyEncryptionKey, value: key);
      }
      encryptionKey = key;
    }

    final keyBytes = base64Url.decode(encryptionKey);
    final HiveCipher? webSafeCipher = kIsWeb ? null : HiveAesCipher(keyBytes);

    // Ouvre les boîtes Hive (chiffrées pour les données sensibles)
    if (!kIsWeb) {
      _settingsBox = await Hive.openBox(_boxName('settings'));
    }
    _secureSettingsBox = await Hive.openBox(
      _boxName(AppConstants.secureSettingsBox),
      encryptionCipher: webSafeCipher,
    );
    await _migrateSensitiveSettings();
    _usersBox = await Hive.openBox(_boxName('users'), encryptionCipher: webSafeCipher);
    _conversationsBox = await Hive.openBox(_boxName('conversations'),
        encryptionCipher: webSafeCipher);
    _messagesBox =
        await Hive.openBox(_boxName('messages'), encryptionCipher: webSafeCipher);
    _groupsBox = await Hive.openBox(_boxName('groups'), encryptionCipher: webSafeCipher);
    _storiesBox = await Hive.openBox(_boxName('stories'), encryptionCipher: webSafeCipher);
    _phoneDirectoryBox = await Hive.openBox(_boxName('phone_directory'),
        encryptionCipher: webSafeCipher);

    // Crée un ID utilisateur local s'il n'existe pas
    if (_secureSettingsBox.get(AppConstants.keyUserId) == null) {
      final userId = const Uuid().v4();
      await _secureSettingsBox.put(AppConstants.keyUserId, userId);
    }
    if (_secureSettingsBox.get(AppConstants.keyDeviceSecret) == null) {
      final deviceSecret = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _secureSettingsBox.put(
        AppConstants.keyDeviceSecret,
        deviceSecret,
      );
    }
  }

  static Future<void> _migrateSensitiveSettings() async {
    const sensitiveKeys = [
      AppConstants.keyUserId,
      AppConstants.keyUserName,
      AppConstants.keyUserBio,
      AppConstants.keyUserPhoto,
      AppConstants.keyUserPhone,
    ];
    for (final key in sensitiveKeys) {
      if (_secureSettingsBox.containsKey(key)) continue;
      if (!_settingsBox.containsKey(key)) continue;
      await _secureSettingsBox.put(key, _settingsBox.get(key));
      await _settingsBox.delete(key);
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
      _secureSettingsBox.get(AppConstants.keyUserId) as String;

  static String get deviceSecret =>
      _secureSettingsBox.get(AppConstants.keyDeviceSecret) as String;

  static String get userName =>
      _secureSettingsBox
          .get(AppConstants.keyUserName, defaultValue: 'Utilisateur')
          as String;

  static Future<void> setUserName(String name) async {
    await _secureSettingsBox.put(AppConstants.keyUserName, name);
  }

  static String? get userBio =>
      _secureSettingsBox.get(AppConstants.keyUserBio) as String?;

  static Future<void> setUserBio(String? bio) async {
    await _secureSettingsBox.put(AppConstants.keyUserBio, bio);
  }

  static String? get userPhotoPath =>
      _secureSettingsBox.get(AppConstants.keyUserPhoto) as String?;

  static Future<void> setUserPhotoPath(String? path) async {
    await _secureSettingsBox.put(AppConstants.keyUserPhoto, path);
  }

  /// Numéro de téléphone (digits, sans espaces) — utilisé pour le mode internet
  static String? get userPhone =>
      _secureSettingsBox.get(AppConstants.keyUserPhone) as String?;

  static Future<void> setUserPhone(String? phone) async {
    final normalized = phone == null ? null : normalizePhone(phone);
    await _secureSettingsBox.put(AppConstants.keyUserPhone, normalized);
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

  static bool get autoCleanup =>
      _settingsBox.get(AppConstants.keyAutoCleanup, defaultValue: true) as bool;

  static Future<void> setAutoCleanup(bool value) async {
    await _settingsBox.put(AppConstants.keyAutoCleanup, value);
  }

  static bool get autoPlayStories => _settingsBox
      .get(AppConstants.keyAutoPlayStories, defaultValue: true) as bool;

  static Future<void> setAutoPlayStories(bool value) async {
    await _settingsBox.put(AppConstants.keyAutoPlayStories, value);
  }

  static int get storyViewDuration => _settingsBox
      .get(AppConstants.keyStoryViewDuration, defaultValue: 5) as int;

  static Future<void> setStoryViewDuration(int seconds) async {
    await _settingsBox.put(AppConstants.keyStoryViewDuration, seconds);
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
