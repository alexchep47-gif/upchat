import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';

/// Service de stockage local (Hive + Secure Storage)
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

  static String _boxName(String name) => kIsWeb ? '${name}_web_v2' : name;

  static Future<void> init() async {
    if (kIsWeb) {
      _settingsBox = await Hive.openBox(_boxName('settings'));
    }

    String? encryptionKey = kIsWeb
        ? _settingsBox.get(AppConstants.keyEncryptionKey) as String?
        : await _secureStorage.read(key: AppConstants.keyEncryptionKey);

    if (encryptionKey == null) {
      final key = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      if (kIsWeb) {
        await _settingsBox.put(AppConstants.keyEncryptionKey, key);
      } else {
        await _secureStorage.write(
          key: AppConstants.keyEncryptionKey,
          value: key,
        );
      }
      encryptionKey = key;
    }

    final keyBytes = base64Url.decode(encryptionKey);
    final HiveCipher? webSafeCipher = kIsWeb ? null : HiveAesCipher(keyBytes);

    if (!kIsWeb) {
      _settingsBox = await Hive.openBox(_boxName('settings'));
    }
    _secureSettingsBox = await Hive.openBox(
      _boxName(AppConstants.secureSettingsBox),
      encryptionCipher: webSafeCipher,
    );
    await _migrateSensitiveSettings();
    _usersBox = await Hive.openBox(
      _boxName('users'),
      encryptionCipher: webSafeCipher,
    );
    _conversationsBox = await Hive.openBox(
      _boxName('conversations'),
      encryptionCipher: webSafeCipher,
    );
    _messagesBox = await Hive.openBox(
      _boxName('messages'),
      encryptionCipher: webSafeCipher,
    );
    _groupsBox = await Hive.openBox(
      _boxName('groups'),
      encryptionCipher: webSafeCipher,
    );
    _storiesBox = await Hive.openBox(
      _boxName('stories'),
      encryptionCipher: webSafeCipher,
    );
    _phoneDirectoryBox = await Hive.openBox(
      _boxName('phone_directory'),
      encryptionCipher: webSafeCipher,
    );

    if (_secureSettingsBox.get(AppConstants.keyUserId) == null) {
      final userId = const Uuid().v4();
      await _secureSettingsBox.put(AppConstants.keyUserId, userId);
    }
    if (_secureSettingsBox.get(AppConstants.keyDeviceSecret) == null) {
      final deviceSecret = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await _secureSettingsBox.put(AppConstants.keyDeviceSecret, deviceSecret);
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

  static Box get settings => _settingsBox;
  static Box get users => _usersBox;
  static Box get conversations => _conversationsBox;
  static Box get messages => _messagesBox;
  static Box get groups => _groupsBox;
  static Box get stories => _storiesBox;
  static Box get phoneDirectory => _phoneDirectoryBox;

  static String get userId =>
      _secureSettingsBox.get(AppConstants.keyUserId) as String;

  /// Aligne l’ID local avec Firebase Auth (obligatoire pour le relais internet).
  static Future<void> setUserId(String id) async {
    if (id.trim().isEmpty) return;
    await _secureSettingsBox.put(AppConstants.keyUserId, id.trim());
  }

  static String get deviceSecret =>
      _secureSettingsBox.get(AppConstants.keyDeviceSecret) as String;

  static String get userName =>
      _secureSettingsBox.get(
            AppConstants.keyUserName,
            defaultValue: 'Utilisateur',
          )
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

  static String? get userPhone =>
      _secureSettingsBox.get(AppConstants.keyUserPhone) as String?;

  static Future<void> setUserPhone(String? phone) async {
    final normalized = phone == null ? null : normalizePhone(phone);
    await _secureSettingsBox.put(AppConstants.keyUserPhone, normalized);
  }

  /// Normalise un numéro pour stockage / lookup.
  /// - garde le + si présent
  /// - Cameroun : 9 chiffres commençant par 6 → +237…
  /// - 237 + 9 chiffres → +237…
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // 00 préfixe international
    if (digits.startsWith('00') && digits.length > 4) {
      digits = digits.substring(2);
    }

    // Cameroun local 6XX XXX XXX (9 chiffres)
    if (digits.length == 9 && digits.startsWith('6')) {
      return '+237$digits';
    }
    // Déjà avec indicatif 237 sans +
    if (digits.length == 12 && digits.startsWith('237')) {
      return '+$digits';
    }
    // Autre format international saisi sans +
    if (digits.length >= 10 && digits.length <= 15 && !trimmed.startsWith('+')) {
      // Si l'utilisateur a collé 2376… déjà couvert ; sinon on conserve les chiffres
      // mais on préfère le + pour les lookups serveur.
      if (digits.startsWith('237') && digits.length >= 12) {
        return '+${digits.substring(0, 12)}';
      }
    }
    if (trimmed.startsWith('+') || digits.length >= 10) {
      return '+$digits';
    }
    return digits;
  }

  /// Variantes à essayer côté lookup (même personne, saisie différente).
  static List<String> phoneLookupCandidates(String raw) {
    final primary = normalizePhone(raw);
    if (primary.isEmpty) return const [];
    final digits = primary.replaceAll(RegExp(r'[^0-9]'), '');
    final set = <String>{primary, digits, '+$digits'};
    if (digits.startsWith('237') && digits.length >= 12) {
      final local = digits.substring(3);
      set.add(local);
      set.add('+237$local');
      set.add('237$local');
    } else if (digits.length == 9 && digits.startsWith('6')) {
      set.add('+237$digits');
      set.add('237$digits');
    }
    return set.where((e) => e.isNotEmpty).toList();
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

  static bool get autoPlayStories =>
      _settingsBox.get(AppConstants.keyAutoPlayStories, defaultValue: true)
          as bool;

  static Future<void> setAutoPlayStories(bool value) async {
    await _settingsBox.put(AppConstants.keyAutoPlayStories, value);
  }

  static int get storyViewDuration =>
      _settingsBox.get(AppConstants.keyStoryViewDuration, defaultValue: 5)
          as int;

  static Future<void> setStoryViewDuration(int seconds) async {
    await _settingsBox.put(AppConstants.keyStoryViewDuration, seconds);
  }

  static bool get biometricLockEnabled =>
      _secureSettingsBox.get(AppConstants.keyBiometricLock, defaultValue: false)
          as bool;

  static Future<void> setBiometricLockEnabled(bool enabled) async {
    await _secureSettingsBox.put(AppConstants.keyBiometricLock, enabled);
  }

  static Future<void> clearChats() async {
    await _messagesBox.clear();
    await _conversationsBox.clear();
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
