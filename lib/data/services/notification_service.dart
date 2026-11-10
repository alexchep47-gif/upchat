import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/message_model.dart';
import 'storage_service.dart';
import '../../core/constants/app_constants.dart';

/// Notifications locales pour les messages reçus pendant que le processus UpChat
/// est actif. Aucune permission n’est demandée pendant l’initialisation.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Appelé uniquement depuis Réglages, jamais automatiquement au démarrage.
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    await initialize();

    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (android ?? true) && (ios ?? true);
  }

  Future<void> showMessage(MessageModel message) async {
    if (kIsWeb || message.isMe || message.type != MessageType.text) return;
    await initialize();

    final box = StorageService.settings;
    final sounds = box.get(AppConstants.keyNotificationSounds, defaultValue: true) as bool;
    final vibration = box.get(AppConstants.keyNotificationVibration, defaultValue: true) as bool;
    final showPreview = box.get(AppConstants.keyNotificationPreview, defaultValue: false) as bool;
    if (!sounds && !vibration && !showPreview) return;

    final body = showPreview ? message.content : 'Nouveau message';
    final androidDetails = AndroidNotificationDetails(
      'upchat_messages',
      'Messages',
      channelDescription: 'Notifications des nouveaux messages UpChat',
      importance: Importance.high,
      priority: Priority.high,
      playSound: sounds,
      enableVibration: vibration,
      groupKey: 'upchat_messages',
    );
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: sounds,
      threadIdentifier: 'upchat_messages',
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
    final id = message.id.hashCode & 0x7fffffff;
    await _plugin.show(id, message.senderName, body, details, payload: message.conversationId);
  }
}
