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
import 'firebase_auth_service.dart';

class InternetLookupException implements Exception {
  final int? statusCode;
  final String message;
  const InternetLookupException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Mode internet optionnel (hybride)
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
  Timer? _inboxTimer;
  Timer? _reconnectTimer;
  bool _flushInProgress = false;
  bool _inboxPullInProgress = false;
  bool _reconnectAttemptInProgress = false;
  Future<bool>? _reconnectFuture;
  String? _serverAuthMode;

  final List<Map<String, dynamic>> _outbox = [];
  final Map<String, DateTime> _onlinePeers = {};

  Function(MessageModel)? onMessageReceived;
  Function(String messageId, MessageStatus status)? onMessageStatus;
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

  @visibleForTesting
  static String selectBearerToken({
    required bool firebaseAdmin,
    required String? firebaseToken,
    required String deviceSecret,
  }) {
    if (firebaseAdmin) {
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw StateError('Un ID token Firebase est requis par le relais.');
      }
      return firebaseToken;
    }
    return deviceSecret;
  }

  Future<Map<String, String>> get _headers async {
    final firebaseUser = FirebaseAuthService.instance.currentUser;
    final firebaseToken = _serverAuthMode == 'firebase-admin'
        ? await firebaseUser?.getIdToken()
        : null;
    final token = selectBearerToken(
      firebaseAdmin: _serverAuthMode == 'firebase-admin',
      firebaseToken: firebaseToken,
      deviceSecret: StorageService.deviceSecret,
    );
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-UpChat-Client': AppConstants.appVersion,
    };
  }

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
    _enabled =
        StorageService.settings.get(
              AppConstants.keyInternetMode,
              defaultValue: false,
            )
            as bool;
    if (_enabled) await _start();
  }

  Future<void> _start() async {
    debugPrint('InternetService: démarrage du mode hybride');
    _isOnline = false;
    _isConnectedToSignaling = false;
    await _connectSignaling();

    if (_isConnectedToSignaling) {
      _isOnline = true;
      _cancelReconnect();
      onConnectivityChanged?.call(true);
      await _flushOutbox();
      _startHeartbeat();
      _startInboxPolling();
    } else {
      onConnectivityChanged?.call(false);
      _scheduleReconnect();
    }
  }

  Future<void> _stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _inboxTimer?.cancel();
    _inboxTimer = null;
    _cancelReconnect();
    _isOnline = false;
    _isConnectedToSignaling = false;
    _onlinePeers.clear();
    onConnectivityChanged?.call(false);
    debugPrint('InternetService: mode hybride arrêté');
  }

  Future<void> _connectSignaling() async {
    try {
      await _refreshServerAuthMode();
      final phone = StorageService.userPhone;
      final firebaseUser = FirebaseAuthService.instance.currentUser;
      final useFirebaseAuth = _serverAuthMode == 'firebase-admin';
      final body = {
        'userId': firebaseUser?.uid ?? StorageService.userId,
        'name': StorageService.userName,
        if (!useFirebaseAuth) 'deviceSecret': StorageService.deviceSecret,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };

      final res = await http
          .post(
            _uri('/api/register'),
            headers: await _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _isConnectedToSignaling = true;
        _onlinePeers[StorageService.userId] = DateTime.now();
        debugPrint('InternetService: enregistré sur signalisation (phone=${phone ?? "-"})');
      } else if (res.statusCode == 409) {
        // Numéro déjà pris par un autre userId
        debugPrint('InternetService: register 409 — numéro déjà associé à un autre compte');
        _isConnectedToSignaling = false;
        throw StateError(
          'Ce numéro est déjà lié à un autre compte UpChat sur le serveur.',
        );
      } else {
        debugPrint('InternetService: register HTTP ${res.statusCode} ${res.body}');
        _isConnectedToSignaling = false;
      }
    } catch (e) {
      debugPrint('InternetService: erreur signalisation: $e');
      _isConnectedToSignaling = false;
      if (e is StateError) rethrow;
    }
  }

  Future<void> _refreshServerAuthMode() async {
    try {
      final response = await http
          .get(_uri('/api/health'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final mode = decoded['auth'];
      if (mode == 'firebase-admin' || mode == 'legacy-device-token') {
        _serverAuthMode = mode as String;
      }
    } catch (error) {
      debugPrint('InternetService: lecture du mode serveur impossible: $error');
    }
  }

  void _scheduleReconnect() {
    if (!_enabled || _reconnectTimer != null) return;
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_enabled) {
        _cancelReconnect();
        return;
      }
      if (_reconnectAttemptInProgress) return;

      _reconnectAttemptInProgress = true;
      try {
        await _connectSignaling();
        if (!_enabled || !_isConnectedToSignaling) return;

        _isOnline = true;
        _cancelReconnect();
        onConnectivityChanged?.call(true);
        await _flushOutbox();
        _startHeartbeat();
        _startInboxPolling();
      } finally {
        _reconnectAttemptInProgress = false;
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _markDisconnected() {
    _isOnline = false;
    _isConnectedToSignaling = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _inboxTimer?.cancel();
    _inboxTimer = null;
    onConnectivityChanged?.call(false);
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(AppConstants.presenceHeartbeat, (_) async {
      if (!_enabled || !_isOnline) return;
      try {
        await http
            .post(
              _uri('/api/presence'),
              headers: await _headers,
              body: jsonEncode({
                'userId': StorageService.userId,
                'phone': StorageService.userPhone,
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        _markDisconnected();
      }
    });
  }

  Future<bool> _reconnectSignaling() {
    final active = _reconnectFuture;
    if (active != null) return active;

    final future = () async {
      _isConnectedToSignaling = false;
      await _connectSignaling();
      if (!_isConnectedToSignaling) {
        _scheduleReconnect();
        return false;
      }

      _isOnline = true;
      _cancelReconnect();
      onConnectivityChanged?.call(true);
      _startHeartbeat();
      _startInboxPolling();
      return true;
    }();

    _reconnectFuture = future.whenComplete(() => _reconnectFuture = null);
    return _reconnectFuture!;
  }

  void _startInboxPolling() {
    _inboxTimer?.cancel();
    _inboxTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pullInbox();
    });
    _pullInbox();
  }

  Future<void> _pullInbox({bool retryAfterAuth = true}) async {
    if (_inboxPullInProgress ||
        !_enabled ||
        !_isOnline ||
        !_isConnectedToSignaling) {
      return;
    }
    _inboxPullInProgress = true;
    try {
      final res = await http
          .get(_uri('/api/inbox', {'limit': '100'}), headers: await _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 401) {
        _isConnectedToSignaling = false;
        if (retryAfterAuth && await _reconnectSignaling()) {
          await _pullInbox(retryAfterAuth: false);
        }
        return;
      }
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      final rawMessages = decoded is Map<String, dynamic>
          ? decoded['messages']
          : null;
      if (rawMessages is! List) return;
      for (final raw in rawMessages) {
        if (raw is Map) handleIncoming(Map<String, dynamic>.from(raw));
      }
    } catch (error) {
      debugPrint('InternetService: inbox error: $error');
      _markDisconnected();
    } finally {
      _inboxPullInProgress = false;
    }
  }

  /// Recherche un utilisateur par numéro (toutes variantes 6… / +237…).
  Future<UserModel?> lookupByPhone(
    String rawPhone, {
    bool requireRegisteredAccount = false,
  }) async {
    final candidates = StorageService.phoneLookupCandidates(rawPhone);
    if (candidates.isEmpty) return null;

    // Cache local sur chaque variante
    for (final phone in candidates) {
      final local = _directory.findLocal(phone);
      if (local != null) {
        if (!requireRegisteredAccount) return local;
        // Même en mode strict, un contact local issu d'un lookup serveur suffit
        if (local.id.isNotEmpty) return local;
      }
    }

    if (!_isOnline || !_isConnectedToSignaling) {
      await _connectSignaling();
      if (_isConnectedToSignaling) {
        _isOnline = true;
        _startHeartbeat();
        if (_enabled) _startInboxPolling();
      }
    }
    if (!_isOnline || !_isConnectedToSignaling) {
      if (requireRegisteredAccount) {
        throw const InternetLookupException(
          'Le serveur UpChat est indisponible pour vérifier ce numéro.',
        );
      }
      return null;
    }

    try {
      // Une seule requête avec le format canonique ; le serveur élargit aussi
      final phone = candidates.first;
      final res = await http
          .get(_uri('/api/lookup', {'phone': phone}), headers: await _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['found'] == true) {
          final resolvedPhone =
              data['phone'] as String? ?? StorageService.normalizePhone(rawPhone);
          final user = UserModel(
            id: data['userId'] as String,
            name: data['name'] as String? ?? resolvedPhone,
            phoneNumber: resolvedPhone,
            lastSeen: data['lastSeen'] != null
                ? DateTime.tryParse(data['lastSeen'] as String) ??
                      DateTime.now()
                : DateTime.now(),
          );
          await _directory.upsert(user);
          return user;
        }
      } else if (res.statusCode == 401) {
        await _connectSignaling();
        if (_isConnectedToSignaling) {
          return await lookupByPhone(
            rawPhone,
            requireRegisteredAccount: requireRegisteredAccount,
          );
        }
      } else if (res.statusCode >= 500) {
        throw StateError('Le serveur UpChat est temporairement indisponible.');
      }
    } catch (e) {
      debugPrint('InternetService: lookup error: $e');
      if (e is StateError) rethrow;
    }
    return null;
  }

  /// Ré-enregistre sur le serveur même si le mode internet n'était pas actif.
  /// Nécessaire après saisie du numéro dans le profil.
  Future<void> reregister({bool force = false}) async {
    if (!force && !(_enabled && _isOnline)) {
      // Tentative best-effort : publier le numéro dès qu'on a du réseau
      try {
        await _connectSignaling();
        if (_isConnectedToSignaling) {
          _isOnline = true;
          if (_enabled) {
            _startHeartbeat();
            _startInboxPolling();
          }
        }
      } catch (e) {
        debugPrint('InternetService: reregister best-effort: $e');
      }
      return;
    }
    await _connectSignaling();
  }

  Future<bool> sendMessage({
    String? messageId,
    required String targetUserId,
    required String conversationId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaPath,
    String? targetPhone,
  }) async {
    final payload = {
      'type': 'message',
      'id': messageId ?? _uuid.v4(),
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'senderPhone': StorageService.userPhone,
      'targetUserId': targetUserId,
      if (targetPhone != null) 'targetPhone': targetPhone,
      'messageType': type.name,
      'content': text,
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

  Future<bool> _transmit(
    Map<String, dynamic> payload, {
    bool retryAfterAuth = true,
  }) async {
    try {
      final res = await http
          .post(
            _uri('/api/message'),
            headers: await _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final messageId = payload['id'];
        if (messageId is String) {
          onMessageStatus?.call(messageId, MessageStatus.sent);
        }
        debugPrint('InternetService: transmission réussie');
        return true;
      }
      debugPrint('InternetService: transmit HTTP ${res.statusCode}');
      if (res.statusCode == 401 &&
          retryAfterAuth &&
          await _reconnectSignaling()) {
        return await _transmit(payload, retryAfterAuth: false);
      }
      if (res.statusCode >= 400 &&
          res.statusCode < 500 &&
          res.statusCode != 408 &&
          res.statusCode != 425 &&
          res.statusCode != 429) {
        return false;
      }
      await _queuePayload(payload);
      _markDisconnected();
      return false;
    } catch (e) {
      debugPrint('InternetService: échec transmission: $e');
      await _queuePayload(payload);
      _markDisconnected();
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
    if (_flushInProgress || _outbox.isEmpty) return;
    _flushInProgress = true;
    try {
      final pending = List<Map<String, dynamic>>.from(_outbox);
      _outbox.clear();

      for (final payload in pending) {
        final ok = await _transmit(payload);
        if (ok) {
          await StorageService.messages.delete('outbox_${payload['id']}');
        } else if (!_outbox.any((item) => item['id'] == payload['id'])) {
          _outbox.add(payload);
        }
      }
    } finally {
      _flushInProgress = false;
    }
  }

  Future<void> onConnectivityChange(bool online) async {
    final wasOnline = _isOnline;
    _isOnline = online;
    onConnectivityChanged?.call(online);

    if (online && !wasOnline && _enabled) {
      await _connectSignaling();
      if (_isConnectedToSignaling) {
        _isOnline = true;
        _cancelReconnect();
        await _flushOutbox();
        _startHeartbeat();
        _startInboxPolling();
      } else {
        _scheduleReconnect();
      }
    } else if (!online) {
      _heartbeatTimer?.cancel();
      _inboxTimer?.cancel();
      _inboxTimer = null;
      _isConnectedToSignaling = false;
      _scheduleReconnect();
    }
  }

  void handleIncoming(Map<String, dynamic> map) {
    final message = MessageModel(
      id: map['id'] as String? ?? _uuid.v4(),
      conversationId:
          map['conversationId'] as String? ??
          map['senderId'] as String? ??
          map['senderUserId'] as String? ??
          '',
      senderId:
          map['senderId'] as String? ?? map['senderUserId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Inconnu',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['messageType'] ?? map['type']),
        orElse: () => MessageType.text,
      ),
      content: map['content'] as String? ?? '',
      mediaPath: map['mediaPath'] as String?,
      isMe: false,
      status: MessageStatus.delivered,
    );

    final senderPhone = map['senderPhone'] as String?;
    if (senderPhone != null && senderPhone.isNotEmpty) {
      _directory.upsert(
        UserModel(
          id: message.senderId,
          name: message.senderName,
          phoneNumber: senderPhone,
        ),
      );
    }

    onMessageReceived?.call(message);
  }
}
