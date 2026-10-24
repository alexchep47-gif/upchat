import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';
import 'storage_service.dart';

/// Mode internet optionnel (hybride)
///
/// Quand activé et qu'il y a une connexion :
/// - Permet Android ↔ iPhone / iPhone ↔ iPhone
/// - Portée illimitée (via réseau)
/// - Base pour appels vocaux longue distance
///
/// Architecture :
/// - Découverte via un canal de signalisation léger (à brancher)
/// - Messages relayés quand les deux pairs sont en ligne
/// - Le mode offline (Nearby) reste prioritaire en local
///
/// Note : un vrai déploiement cross-plateforme nécessite un petit
/// serveur de signalisation (WebSocket). Ici on prépare toute la
/// couche app + file d'attente hors ligne → en ligne.
class InternetService {
  static final InternetService _instance = InternetService._internal();
  factory InternetService() => _instance;
  InternetService._internal();

  final Uuid _uuid = const Uuid();

  bool _enabled = false;
  bool _isOnline = false;
  bool _isConnectedToSignaling = false;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  // File d'attente des messages à envoyer quand on repasse en ligne
  final List<Map<String, dynamic>> _outbox = [];

  // Contacts connus en mode internet (userId → lastSeen)
  final Map<String, DateTime> _onlinePeers = {};

  Function(MessageModel)? onMessageReceived;
  Function(String userId, bool online)? onPeerPresence;
  Function(bool online)? onConnectivityChanged;

  bool get isEnabled => _enabled;
  bool get isOnline => _isOnline;
  bool get isReady => _enabled && _isOnline;
  Map<String, DateTime> get onlinePeers => Map.unmodifiable(_onlinePeers);

  /// Active / désactive le mode internet
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await StorageService.settings.put('internet_mode', value);

    if (value) {
      await _start();
    } else {
      await _stop();
    }
  }

  Future<void> loadPreference() async {
    _enabled = StorageService.settings.get('internet_mode', defaultValue: false) as bool;
    if (_enabled) await _start();
  }

  Future<void> _start() async {
    debugPrint('InternetService: démarrage du mode hybride');
    // Détection basique de connectivité (à enrichir avec connectivity_plus)
    _isOnline = !kIsWeb; // stub — en prod utiliser connectivity_plus
    // Sur web on considère souvent "en ligne"
    if (kIsWeb) _isOnline = true;

    onConnectivityChanged?.call(_isOnline);

    if (_isOnline) {
      await _connectSignaling();
      await _flushOutbox();
    }
  }

  Future<void> _stop() async {
    _reconnectTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _channelSubscription = null;
    _isConnectedToSignaling = false;
    _onlinePeers.clear();
    debugPrint('InternetService: mode hybride arrêté');
  }

  /// Connexion au canal WebSocket de signalisation.
  Future<void> _connectSignaling() async {
    if (!_enabled || !_isOnline || _isConnectedToSignaling) return;
    try {
      await _channelSubscription?.cancel();
      await _channel?.sink.close();
      final channel = WebSocketChannel.connect(Uri.parse(AppConstants.signalingUrl));
      _channel = channel;
      await channel.ready;
      _isConnectedToSignaling = true;
      _reconnectAttempt = 0;
      _send({'type': 'register', 'userId': StorageService.userId, 'userName': StorageService.userName});
      _channelSubscription = channel.stream.listen(
        (event) => _handleSignal(event),
        onError: (Object error, StackTrace stack) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      debugPrint('InternetService: signalisation connectée');
    } catch (error) {
      _isConnectedToSignaling = false;
      debugPrint('InternetService: connexion signalisation impossible: $error');
      _scheduleReconnect();
    }
  }

  void _send(Map<String, dynamic> payload) {
    if (_isConnectedToSignaling) _channel?.sink.add(jsonEncode(payload));
  }

  void _scheduleReconnect() {
    if (!_enabled || !_isOnline || _reconnectTimer?.isActive == true) return;
    _isConnectedToSignaling = false;
    final delaySeconds = (_reconnectAttempt++ + 1).clamp(1, 30).toInt();
    final delay = Duration(seconds: delaySeconds);
    _reconnectTimer = Timer(delay, _connectSignaling);
  }

  void _handleSignal(dynamic raw) {
    try {
      final map = jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>)) as Map<String, dynamic>;
      switch (map['type']) {
        case 'presence':
          final userId = map['userId'] as String?;
          if (userId != null && userId != StorageService.userId) {
            _onlinePeers[userId] = DateTime.now();
            onPeerPresence?.call(userId, map['online'] != false);
          }
        case 'message':
          if (map['targetUserId'] == StorageService.userId) handleIncoming(map);
      }
    } catch (error) {
      debugPrint('InternetService: payload signal invalide: $error');
    }
  }

  /// Envoie un message via internet (ou le met en file d'attente)
  Future<bool> sendMessage({
    required String targetUserId,
    required String conversationId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaPath,
  }) async {
    final payload = {
      'type': 'message',
      'id': _uuid.v4(),
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'targetUserId': targetUserId,
      'messageType': type.name,
      'content': text,
      'mediaPath': mediaPath,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (!_isOnline || !_isConnectedToSignaling) {
      _outbox.add(payload);
      await StorageService.messages.put('outbox_${payload['id']}', payload);
      debugPrint('InternetService: message mis en file d\'attente (hors ligne)');
      return false;
    }

    return await _transmit(payload);
  }

  Future<bool> _transmit(Map<String, dynamic> payload) async {
    try {
      _send(payload);
      debugPrint('InternetService: transmission → ${payload['targetUserId']}');
      return _isConnectedToSignaling;
    } catch (e) {
      debugPrint('InternetService: échec transmission: $e');
      _outbox.add(payload);
      return false;
    }
  }

  Future<void> _flushOutbox() async {
    if (_outbox.isEmpty) return;

    final pending = List<Map<String, dynamic>>.from(_outbox);
    _outbox.clear();

    for (final payload in pending) {
      final ok = await _transmit(payload);
      if (!ok) {
        _outbox.add(payload);
      } else {
        await StorageService.messages.delete('outbox_${payload['id']}');
      }
    }
  }

  /// Appelle quand la connectivité change
  Future<void> onConnectivityChange(bool online) async {
    final wasOnline = _isOnline;
    _isOnline = online;
    onConnectivityChanged?.call(online);

    if (online && !wasOnline && _enabled) {
      await _connectSignaling();
      await _flushOutbox();
    } else if (!online) {
      _isConnectedToSignaling = false;
    }
  }

  /// Réception d'un message depuis le réseau
  void handleIncoming(Map<String, dynamic> map) {
    if (map['senderId'] == StorageService.userId) return;
    final message = MessageModel(
      id: map['id'] as String? ?? _uuid.v4(),
      conversationId: map['conversationId'] as String? ?? map['senderId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Inconnu',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['messageType'],
        orElse: () => MessageType.text,
      ),
      content: map['content'] as String? ?? '',
      mediaPath: map['mediaPath'] as String?,
      isMe: false,
      status: MessageStatus.delivered,
    );
    onMessageReceived?.call(message);
  }
}
