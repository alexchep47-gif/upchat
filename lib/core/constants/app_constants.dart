/// Constantes globales de l'application UpChat
class AppConstants {
  static const String appName = 'UpChat';
  static const String appVersion = '1.1.0';
  static const String appTagline = 'Messagerie 100 % offline';

  // Couleurs WhatsApp-like
  static const int primaryGreen = 0xFF128C7E;
  static const int accentGreen = 0xFF25D366;
  static const int lightGreen = 0xFFDCF8C6;
  static const int darkGreen = 0xFF075E54;

  // Nearby Connections
  static const String serviceId = 'com.upchat.p2p';
  static const String strategy = 'P2P_CLUSTER';

  // Durées
  static const Duration storyExpiration = Duration(hours: 24);
  static const Duration discoveryTimeout = Duration(seconds: 30);
  static const Duration mediaRetention = Duration(days: 7);

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
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyEncryptionKey = 'encryption_key';
}
