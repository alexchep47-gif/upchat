import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'phone_directory_service.dart';
import 'storage_service.dart';

/// Mode internet optionnel (hybride)
///
/// Architecture téléphone :
/// 1. L'utilisateur enregistre son numéro (optionnel offline, recommandé en ligne)
/// 2. À l'activation du mode internet → POST /register { userId, phone, name }
/// 3. Lookup contact → GET /lookup?phone=...
/// 4. Messages relayés via le serveur de signalisation quand les deux sont en ligne
/// 5. Le mode offline (Nearby) reste prioritaire en local
class InternetService {
  static final InternetService _instance = InternetService._internal();
  factory InternetService() => _instance;
  InternetService._internal();

  final Uuid _uuid = const Uuid();
  final PhoneDirectoryService _directory = PhoneDirectoryService();

  bool _enabled = false;
  bool _isOnline = false;
  bool _isConnectedToSignaling = false;
  Timer? _heartbeatTimer;

  // File d'attente des messages à envoyer quand on repasse en ligne
  final List<Map<String, dynamic>> _outbox = [];

  // Contacts connus en mode internet (userId → lastSeen)
  final Map<String, DateTime> _onlinePeers = {};

  Function(MessageModel)? onMessageReceived;
  Function(String userId, bool online)? onPeerPresence;
  Function(bool online)? onConnectivityChanged;

  bool get isEnabled => _enabled;
  bool get isOnline => _isOnline;
  bool get isReady => _enabled && _isOnline && _isConnectedToSignaling;
  Map<String, DateTime> get onlinePeers => Map.unmodifiable(_onlinePeers);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConstants.signalingBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${StorageService.deviceSecret}',
        'X-UpChat-Client': AppConstants.appVersion,
      };

  /// Active / désactive le mode internet
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await StorageService.settings.put(AppConstants.keyInternetMode, value);

    if (value) {
      await _start();
    } else {
      await _stop();
    }
  }

  Future<void> loadPreference() async {
    _outbox.clear();
    for (final key in StorageService.messages.keys) {
      if (!key.toString().startsWith('outbox_')) continue;
      final value = StorageService.messages.get(key);
      if (value is Map) {
        _outbox.add(Map<String, dynamic>.from(value));
      }
    }
    _enabled = StorageService.settings
            .get(AppConstants.keyInternetMode, defaultValue: false) as bool;
    if (_enabled) await _start();
  }

  Future<void> _start() async {
    debugPrint('InternetService: démarrage du mode hybride');
    _isOnline = false;
    _isConnectedToSignaling = false;
    await _connectSignaling();

    if (_isConnectedToSignaling) {
      _isOnline = true;
      onConnectivityChanged?.call(true);
      await _flushOutbox();
      _startHeartbeat();
    } else {
      onConnectivityChanged?.call(false);
    }
  }

  Future<void> _stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isOnline = false;
    _isConnectedToSignaling = false;
    _onlinePeers.clear();
    onConnectivityChanged?.call(false);
    debugPrint('InternetService: mode hybride arrêté');
  }

  /// Connexion + enregistrement sur le serveur de signalisation
  Future<void> _connectSignaling() async {
    try {
      final phone = StorageService.userPhone;
      final body = {
        'userId': StorageService.userId,
        'name': StorageService.userName,
        'deviceSecret': StorageService.deviceSecret,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };

      final res = await http
          .post(
            _uri('/api/register'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _isConnectedToSignaling = true;
        _onlinePeers[StorageService.userId] = DateTime.now();
        debugPrint('InternetService: enregistré sur signalisation');
      } else {
        debugPrint('InternetService: register HTTP ${res.statusCode}');
        _isConnectedToSignaling = false;
      }
    } catch (e) {
      debugPrint('InternetService: erreur signalisation: $e');
      _isConnectedToSignaling = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(AppConstants.presenceHeartbeat, (_) async {
      if (!_enabled || !_isOnline) return;
      try {
        await http
            .post(
              _uri('/api/presence'),
              headers: _headers,
              body: jsonEncode({
                'userId': StorageService.userId,
                'phone': StorageService.userPhone,
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    });
  }

  /// Recherche un utilisateur par numéro de téléphone (réseau + cache local)
  Future<UserModel?> lookupByPhone(
    String rawPhone, {
    bool requireRegisteredAccount = false,
  }) async {
    final phone = StorageService.normalizePhone(rawPhone);
    if (phone.isEmpty) return null;

    // Cache local d'abord
    final local = _directory.findLocal(phone);
    if (!requireRegisteredAccount && local != null) return local;

    if (!_isOnline) return null;

    try {
      final res = await http
          .get(_uri('/api/lookup', {'phone': phone}), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['found'] == true) {
          final user = UserModel(
            id: data['userId'] as String,
            name: data['name'] as String? ?? phone,
            phoneNumber: phone,
            lastSeen: data['lastSeen'] != null
                ? DateTime.tryParse(data['lastSeen'] as String) ?? DateTime.now()
                : DateTime.now(),
          );
          await _directory.upsert(user);
          return user;
        }
      }
    } catch (e) {
      debugPrint('InternetService: lookup error: $e');
    }
    return null;
  }

  /// Met à jour l'enregistrement (après changement de nom / téléphone)
  Future<void> reregister() async {
    if (_enabled && _isOnline) {
      await _connectSignaling();
    }
  }

  /// Envoie un message via internet (ou le met en file d'attente)
  Future<bool> sendMessage({
    required String targetUserId,
    required String conversationId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaPath,
    String? targetPhone,
  }) async {
    final payload = {
      'type': 'message',
      'id': _uuid.v4(),
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'senderPhone': StorageService.userPhone,
      'targetUserId': targetUserId,
      if (targetPhone != null) 'targetPhone': targetPhone,
      'messageType': type.name,
      'content': text,
      // Un chemin local n'est jamais transmissible au serveur. Les médias
      // distants devront utiliser un mediaId/URL chiffré dans une prochaine
      // étape du backend.
      if (mediaPath != null &&
          (mediaPath.startsWith('https://') || mediaPath.startsWith('http://')))
        'mediaPath': mediaPath,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (!_isOnline || !_isConnectedToSignaling) {
      await _queuePayload(payload);
      debugPrint("InternetService: message mis en file d'attente (hors ligne)");
      return false;
    }

    return await _transmit(payload);
  }

  Future<bool> _transmit(Map<String, dynamic> payload) async {
    try {
      final res = await http
          .post(
            _uri('/api/message'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        debugPrint('InternetService: transmission réussie');
        return true;
      }
      debugPrint('InternetService: transmit HTTP ${res.statusCode}');
      await _queuePayload(payload);
      return false;
    } catch (e) {
      debugPrint('InternetService: échec transmission: $e');
      await _queuePayload(payload);
      return false;
    }
  }

  Future<void> _queuePayload(Map<String, dynamic> payload) async {
    final id = payload['id'];
    if (!_outbox.any((item) => item['id'] == id)) {
      _outbox.add(payload);
    }
    await StorageService.messages.put('outbox_$id', payload);
  }

  Future<void> _flushOutbox() async {
    if (_outbox.isEmpty) return;

    final pending = List<Map<String, dynamic>>.from(_outbox);
    _outbox.clear();

    for (final payload in pending) {
      final ok = await _transmit(payload);
      if (ok) {
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
      _startHeartbeat();
    } else if (!online) {
      _heartbeatTimer?.cancel();
      _isConnectedToSignaling = false;
    }
  }

  /// Réception d'un message depuis le réseau
  void handleIncoming(Map<String, dynamic> map) {
    final message = MessageModel(
      id: map['id'] as String? ?? _uuid.v4(),
      conversationId:
          map['conversationId'] as String? ?? map['senderId'] as String? ?? '',
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

    // Enrichit le répertoire local si un téléphone expéditeur est fourni
    final senderPhone = map['senderPhone'] as String?;
    if (senderPhone != null && senderPhone.isNotEmpty) {
      _directory.upsert(UserModel(
        id: message.senderId,
        name: message.senderName,
        phoneNumber: senderPhone,
      ));
    }

    onMessageReceived?.call(message);
  }
}
