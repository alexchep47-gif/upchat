import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/permission_helper.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// Service central P2P (Nearby Connections)
class NearbyService {
  static final NearbyService _instance = NearbyService._internal();
  factory NearbyService() => _instance;
  NearbyService._internal();

  final Nearby _nearby = Nearby();
  final Uuid _uuid = const Uuid();

  bool _isAdvertising = false;
  bool _isDiscovering = false;

  final Map<String, UserModel> _discovered = {};
  final Map<String, String> _connected = {};
  final Map<int, Map<String, dynamic>> _pendingPayloads = {};

  Function(List<UserModel>)? onDevicesChanged;
  Function(MessageModel)? onMessageReceived;
  Function(String endpointId, String userId)? onConnected;
  Function(String endpointId)? onDisconnected;
  Function(String messageId, MessageStatus status)? onStatusUpdate;
  Function(String userId, bool isTyping)? onTyping;

  bool get isAdvertising => _isAdvertising;
  bool get isDiscovering => _isDiscovering;
  List<UserModel> get discoveredDevices => _discovered.values.toList();
  Map<String, String> get connectedEndpoints => Map.unmodifiable(_connected);

  Future<bool> start() async {
    if (kIsWeb) return false;
    if (!await PermissionHelper.hasNearbyPermissions()) {
      debugPrint('NearbyService: permissions Bluetooth/localisation manquantes');
      return false;
    }

    final userName = StorageService.userName;
    try {
      final advertising = await _nearby.startAdvertising(
        userName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: AppConstants.serviceId,
      );

      final discovering = await _nearby.startDiscovery(
        userName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          _discovered[endpointId] = UserModel(
            id: endpointId,
            name: endpointName,
            endpointId: endpointId,
          );
          onDevicesChanged?.call(discoveredDevices);
          _requestConnection(endpointId, userName);
        },
        onEndpointLost: (endpointId) {
          _discovered.remove(endpointId);
          onDevicesChanged?.call(discoveredDevices);
        },
        serviceId: AppConstants.serviceId,
      );
      _isAdvertising = advertising;
      _isDiscovering = discovering;
      return advertising && discovering;
    } catch (e) {
      debugPrint('Erreur Nearby start: $e');
      _isAdvertising = false;
      _isDiscovering = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    _isAdvertising = false;
    _isDiscovering = false;
    _discovered.clear();
    _connected.clear();
    onDevicesChanged?.call([]);
  }

  Future<void> _requestConnection(String endpointId, String userName) async {
    try {
      await _nearby.requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('Erreur requestConnection: $e');
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) _sendIdentity(endpointId);
  }

  void _onDisconnected(String endpointId) {
    _connected.remove(endpointId);
    onDisconnected?.call(endpointId);
  }

  Future<void> _sendIdentity(String endpointId) async {
    final payload = jsonEncode({
      'type': 'identity',
      'userId': StorageService.userId,
      'name': StorageService.userName,
      'bio': StorageService.userBio,
    });
    await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(payload)));
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      _handleBytesPayload(endpointId, payload);
    } else if (payload.type == PayloadType.FILE) {
      _pendingPayloads[payload.id] = {
        'endpointId': endpointId,
        'filePath': payload.filePath,
        'type': 'file',
      };
    }
  }

  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.status == PayloadStatus.SUCCESS) {
      final pending = _pendingPayloads.remove(update.id);
      if (pending != null && pending['type'] == 'file') {
        _handleReceivedFile(endpointId: endpointId, tempPath: pending['filePath'] as String?);
      }
    }
  }

  void _handleBytesPayload(String endpointId, Payload payload) {
    try {
      final data = utf8.decode(payload.bytes!);
      final map = jsonDecode(data) as Map<String, dynamic>;
      final type = map['type'] as String?;

      if (type == 'identity') {
        final userId = map['userId'] as String;
        final name = map['name'] as String? ?? 'Inconnu';
        _connected[endpointId] = userId;
        _discovered[endpointId] = UserModel(
          id: userId,
          name: name,
          bio: map['bio'] as String?,
          endpointId: endpointId,
        );
        onConnected?.call(endpointId, userId);
        onDevicesChanged?.call(discoveredDevices);
        return;
      }

      if (type == 'message') {
        final message = MessageModel(
          id: map['id'] as String? ?? _uuid.v4(),
          conversationId: map['conversationId'] as String? ?? endpointId,
          senderId: map['senderId'] as String? ?? endpointId,
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

        // Accusé de réception automatique
        _sendAck(endpointId, message.id, MessageStatus.delivered);
        return;
      }

      if (type == 'ack') {
        final messageId = map['messageId'] as String?;
        final statusName = map['status'] as String?;
        if (messageId != null && statusName != null) {
          final status = MessageStatus.values.firstWhere(
            (e) => e.name == statusName,
            orElse: () => MessageStatus.sent,
          );
          onStatusUpdate?.call(messageId, status);
        }
        return;
      }

      if (type == 'typing') {
        final userId = map['userId'] as String? ?? endpointId;
        final isTyping = map['isTyping'] as bool? ?? false;
        onTyping?.call(userId, isTyping);
        return;
      }

      if (type == 'media_meta') {
        _pendingPayloads[map['payloadId'] as int? ?? -1] = {
          'endpointId': endpointId,
          'meta': map,
          'type': 'media_meta',
        };
      }
    } catch (e) {
      debugPrint('Erreur parsing payload: $e');
    }
  }

  Future<void> _handleReceivedFile({required String endpointId, String? tempPath}) async {
    if (tempPath == null || kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(dir.path, 'upchat_media', 'received'));
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final ext = p.extension(tempPath);
      final filename = '${_uuid.v4()}$ext';
      final target = File(p.join(targetDir.path, filename));
      await File(tempPath).copy(target.path);

      final message = MessageModel(
        id: _uuid.v4(),
        conversationId: _connected[endpointId] ?? endpointId,
        senderId: _connected[endpointId] ?? endpointId,
        senderName: _discovered[endpointId]?.name ?? 'Contact',
        type: _guessType(ext),
        content: _guessType(ext) == MessageType.image ? '📷 Photo' : '📎 Fichier',
        mediaPath: target.path,
        isMe: false,
        status: MessageStatus.delivered,
      );
      onMessageReceived?.call(message);
      _sendAck(endpointId, message.id, MessageStatus.delivered);
    } catch (e) {
      debugPrint('Erreur réception fichier: $e');
    }
  }

  MessageType _guessType(String ext) {
    final e = ext.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(e)) return MessageType.image;
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(e)) return MessageType.video;
    if (['.m4a', '.aac', '.mp3', '.wav', '.ogg'].contains(e)) return MessageType.audio;
    return MessageType.file;
  }

  /// Envoie un accusé de réception (delivered / read)
  Future<void> _sendAck(String endpointId, String messageId, MessageStatus status) async {
    final payload = jsonEncode({
      'type': 'ack',
      'messageId': messageId,
      'status': status.name,
    });
    try {
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(payload)));
    } catch (_) {}
  }

  /// Notifie que les messages d'une conversation ont été lus
  Future<void> sendReadReceipts(String endpointId, List<String> messageIds) async {
    for (final id in messageIds) {
      await _sendAck(endpointId, id, MessageStatus.read);
    }
  }

  /// Indicateur "en train d'écrire"
  Future<void> sendTyping(String endpointId, bool isTyping) async {
    final payload = jsonEncode({
      'type': 'typing',
      'userId': StorageService.userId,
      'isTyping': isTyping,
    });
    try {
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(payload)));
    } catch (_) {}
  }

  Future<bool> sendTextMessage({
    required String endpointId,
    required String conversationId,
    required String text,
  }) async {
    final messageId = _uuid.v4();
    final payload = jsonEncode({
      'type': 'message',
      'id': messageId,
      'conversationId': conversationId,
      'senderId': StorageService.userId,
      'senderName': StorageService.userName,
      'messageType': MessageType.text.name,
      'content': text,
    });
    try {
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(payload)));
      return true;
    } catch (e) {
      debugPrint('Erreur envoi message: $e');
      return false;
    }
  }

  Future<bool> sendFile({
    required String endpointId,
    required String conversationId,
    required String filePath,
    required MessageType mediaType,
  }) async {
    if (kIsWeb) return false;
    try {
      final meta = jsonEncode({
        'type': 'media_meta',
        'conversationId': conversationId,
        'senderId': StorageService.userId,
        'senderName': StorageService.userName,
        'messageType': mediaType.name,
        'fileName': p.basename(filePath),
      });
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(meta)));
      await _nearby.sendFilePayload(endpointId, filePath);
      return true;
    } catch (e) {
      debugPrint('Erreur envoi fichier: $e');
      return await sendTextMessage(
        endpointId: endpointId,
        conversationId: conversationId,
        text: mediaType == MessageType.image
            ? '📷 Photo'
            : mediaType == MessageType.audio
                ? '🎤 Note vocale'
                : '📎 Fichier',
      );
    }
  }

  Future<void> broadcastText({
    required String conversationId,
    required String text,
  }) async {
    for (final endpointId in _connected.keys) {
      await sendTextMessage(endpointId: endpointId, conversationId: conversationId, text: text);
    }
  }
}
