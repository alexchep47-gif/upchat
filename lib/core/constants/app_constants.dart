/// Constantes globales de l'application UpChat
class AppConstants {
  static const String appName = 'UpChat';
  static const String appVersion = '1.3.1';
  static const String appTagline = 'Messagerie 100 % offline';

  // Auteur
  static const String authorName = 'NEMMEGNE CHEPING ALEXANDRE MERVIN';
  static const String authorNationality = 'Camerounaise';
  static const String authorCredit =
      'Créé par NEMMEGNE CHEPING ALEXANDRE MERVIN\nNationalité : Camerounaise';

  // Couleurs de base
  // Legacy names kept for API compatibility; all active controls use brand blue.
  static const int primaryGreen = 0xFF2AABEE;
  static const int accentGreen = 0xFF2AABEE;
  static const int lightGreen = 0xFFDFF3FF;
  static const int darkGreen = 0xFF229ED9;

  // Nearby Connections
  static const String serviceId = 'com.upchat.p2p';
  static const String strategy = 'P2P_CLUSTER';

  // Signalisation mode internet (Render + PostgreSQL)
  static const String signalingBaseUrl =
      'https://upchat-signal.onrender.com';

  // Durées
  static const Duration storyExpiration = Duration(hours: 24);
  static const Duration discoveryTimeout = Duration(seconds: 30);
  static const Duration mediaRetention = Duration(days: 7);
  static const Duration presenceHeartbeat = Duration(seconds: 45);

  // Limites
  static const int maxImageSizeKb = 800;
  static const int maxGroupMembers = 50;
  static const int maxMessageLength = 2000;
  static const int meshMaxHops = 2;

  // Clés de stockage
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserBio = 'user_bio';
  static const String keyUserPhoto = 'user_photo';
  static const String keyUserPhone = 'user_phone';
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyEncryptionKey = 'encryption_key';
  static const String keyDeviceSecret = 'device_secret';
  static const String keyInternetMode = 'internet_mode';
  static const String keyAutoCleanup = 'auto_cleanup';
  static const String keyAutoPlayStories = 'auto_play_stories';
  static const String keyStoryViewDuration = 'story_view_duration';
  static const String keyReadReceipts = 'settings_read_receipts';
  static const String keyOnlineStatus = 'settings_online_status';
  static const String keyTypingIndicators = 'settings_typing_indicators';
  static const String keyNotificationSounds = 'settings_notification_sounds';
  static const String keyNotificationVibration = 'settings_notification_vibration';
  static const String keyNotificationPreview = 'settings_notification_preview';
  static const String keyEnterToSend = 'settings_enter_to_send';
  static const String keyAutoDownloadMedia = 'settings_auto_download_media';
  static const String keySaveToGallery = 'settings_save_to_gallery';
  static const String keyLowDataMode = 'settings_low_data_mode';
  static const String keyTransparentToolbar = 'settings_transparent_toolbar';
  static const String keyChatFontScale = 'settings_chat_font_scale';

  // Stockage local sensible
  static const String secureSettingsBox = 'secure_settings';
}
