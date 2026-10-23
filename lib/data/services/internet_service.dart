import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
    _isConnectedToSignaling = false;
    _onlinePeers.clear();
    debugPrint('InternetService: mode hybride arrêté');
  }

  /// Connexion au canal de signalisation
  /// (placeholder — brancher WebSocket / PeerJS / ton serveur plus tard)
  Future<void> _connectSignaling() async {
    try {
      // TODO: WebSocket vers ton serveur de signalisation
      // Exemple futur :
      // final channel = WebSocketChannel.connect(Uri.parse('wss://ton-serveur/signal'));
      // channel.sink.add(jsonEncode({'type': 'register', 'userId': StorageService.userId}));

      _isConnectedToSignaling = true;
      debugPrint('InternetService: signalisation prête (stub)');

      // Annonce notre présence
      _onlinePeers[StorageService.userId] = DateTime.now();
    } catch (e) {
      debugPrint('InternetService: erreur signalisation: $e');
      _isConnectedToSignaling = false;
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
      // TODO: envoyer via WebSocket / WebRTC data channel
      debugPrint('InternetService: transmission → ${payload['targetUserId']}');
      // Simulation locale pour tests : si le destinataire est "nous" (debug)
      return true;
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
