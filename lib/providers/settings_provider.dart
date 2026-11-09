import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../data/services/storage_service.dart';

/// Préférences communes à tous les écrans.
///
/// Les valeurs sont persistées dans Hive afin que l’interface reste cohérente
/// après redémarrage et entre les écrans qui utilisent le même provider.
class SettingsProvider extends ChangeNotifier {
  bool _readReceipts = true;
  bool _onlineStatus = true;
  bool _typingIndicators = true;
  bool _notificationSounds = true;
  bool _notificationVibration = true;
  bool _notificationPreview = true;
  bool _enterToSend = false;
  bool _autoDownloadMedia = true;
  bool _saveToGallery = false;
  bool _lowDataMode = false;
  bool _transparentToolbar = true;
  double _chatFontScale = 1;

  SettingsProvider() {
    _load();
  }

  bool get readReceipts => _readReceipts;
  bool get onlineStatus => _onlineStatus;
  bool get typingIndicators => _typingIndicators;
  bool get notificationSounds => _notificationSounds;
  bool get notificationVibration => _notificationVibration;
  bool get notificationPreview => _notificationPreview;
  bool get enterToSend => _enterToSend;
  bool get autoDownloadMedia => _autoDownloadMedia;
  bool get saveToGallery => _saveToGallery;
  bool get lowDataMode => _lowDataMode;
  bool get transparentToolbar => _transparentToolbar;
  double get chatFontScale => _chatFontScale;

  void _load() {
    final box = StorageService.settings;
    _readReceipts = box.get(AppConstants.keyReadReceipts, defaultValue: true) as bool;
    _onlineStatus = box.get(AppConstants.keyOnlineStatus, defaultValue: true) as bool;
    _typingIndicators = box.get(AppConstants.keyTypingIndicators, defaultValue: true) as bool;
    _notificationSounds = box.get(AppConstants.keyNotificationSounds, defaultValue: true) as bool;
    _notificationVibration = box.get(AppConstants.keyNotificationVibration, defaultValue: true) as bool;
    _notificationPreview = box.get(AppConstants.keyNotificationPreview, defaultValue: true) as bool;
    _enterToSend = box.get(AppConstants.keyEnterToSend, defaultValue: false) as bool;
    _autoDownloadMedia = box.get(AppConstants.keyAutoDownloadMedia, defaultValue: true) as bool;
    _saveToGallery = box.get(AppConstants.keySaveToGallery, defaultValue: false) as bool;
    _lowDataMode = box.get(AppConstants.keyLowDataMode, defaultValue: false) as bool;
    _transparentToolbar = box.get(AppConstants.keyTransparentToolbar, defaultValue: true) as bool;
    _chatFontScale = (box.get(AppConstants.keyChatFontScale, defaultValue: 1.0) as num).toDouble();
  }

  Future<void> _set(String key, Object value, void Function() update) async {
    update();
    await StorageService.settings.put(key, value);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool value) => _set(AppConstants.keyReadReceipts, value, () => _readReceipts = value);
  Future<void> setOnlineStatus(bool value) => _set(AppConstants.keyOnlineStatus, value, () => _onlineStatus = value);
  Future<void> setTypingIndicators(bool value) => _set(AppConstants.keyTypingIndicators, value, () => _typingIndicators = value);
  Future<void> setNotificationSounds(bool value) => _set(AppConstants.keyNotificationSounds, value, () => _notificationSounds = value);
  Future<void> setNotificationVibration(bool value) => _set(AppConstants.keyNotificationVibration, value, () => _notificationVibration = value);
  Future<void> setNotificationPreview(bool value) => _set(AppConstants.keyNotificationPreview, value, () => _notificationPreview = value);
  Future<void> setEnterToSend(bool value) => _set(AppConstants.keyEnterToSend, value, () => _enterToSend = value);
  Future<void> setAutoDownloadMedia(bool value) => _set(AppConstants.keyAutoDownloadMedia, value, () => _autoDownloadMedia = value);
  Future<void> setSaveToGallery(bool value) => _set(AppConstants.keySaveToGallery, value, () => _saveToGallery = value);
  Future<void> setLowDataMode(bool value) => _set(AppConstants.keyLowDataMode, value, () => _lowDataMode = value);
  Future<void> setTransparentToolbar(bool value) => _set(AppConstants.keyTransparentToolbar, value, () => _transparentToolbar = value);
  Future<void> setChatFontScale(double value) => _set(AppConstants.keyChatFontScale, value, () => _chatFontScale = value);

  /// Instantané stable pour les écrans qui appliquent plusieurs réglages.
  Map<String, dynamic> toMap() => {
        'readReceipts': _readReceipts,
        'onlineStatus': _onlineStatus,
        'typingIndicators': _typingIndicators,
        'notificationSounds': _notificationSounds,
        'notificationVibration': _notificationVibration,
        'notificationPreview': _notificationPreview,
        'enterToSend': _enterToSend,
        'autoDownloadMedia': _autoDownloadMedia,
        'saveToGallery': _saveToGallery,
        'lowDataMode': _lowDataMode,
        'transparentToolbar': _transparentToolbar,
        'chatFontScale': _chatFontScale,
      };
}
