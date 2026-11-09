import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/app_constants.dart';
import 'firebase_auth_service.dart';
import 'storage_service.dart';

/// Relais temps réel : le serveur ne reçoit qu'une enveloppe opaque.
/// Le texte clair ne doit jamais être placé dans [ciphertext].
class OpaqueRelayService {
  static final OpaqueRelayService instance = OpaqueRelayService._();
  OpaqueRelayService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _keepAlive;
  bool _authenticated = false;

  Stream<Map<String, dynamic>> get incoming => _incoming.stream;
  bool get isConnected => _authenticated;

  Uri get _uri {
    final base = AppConstants.signalingBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return Uri.parse('$base${AppConstants.relayWebSocketPath}');
  }

  Future<void> connect() async {
    await disconnect();
    final channel = WebSocketChannel.connect(_uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) => _handle(data),
      onError: (_) => _authenticated = false,
      onDone: () => _authenticated = false,
    );
    await channel.ready;
    final firebaseUser = FirebaseAuthService.instance.currentUser;
    final token = FirebaseAuthService.instance.isConfigured && firebaseUser != null
        ? await firebaseUser.getIdToken()
        : StorageService.deviceSecret;
    channel.sink.add(jsonEncode({
      'type': 'auth',
      'protocol': AppConstants.relayProtocol,
      'token': token,
    }));
    _keepAlive = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_authenticated) channel.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _handle(Object? raw) {
    if (raw is! String) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    if (message['type'] == 'ready') {
      _authenticated = true;
      return;
    }
    if (message['type'] == 'envelope') _incoming.add(message);
  }

  void send({required String targetUserId, required Map<String, dynamic> envelope}) {
    if (!_authenticated || envelope['ciphertext'] is! String) {
      throw StateError('Une enveloppe chiffrée est requise avant le relais.');
    }
    _channel?.sink.add(jsonEncode({
      'type': 'relay',
      'targetUserId': targetUserId,
      'envelope': envelope,
    }));
  }

  Future<void> disconnect() async {
    _keepAlive?.cancel();
    _keepAlive = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _authenticated = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _incoming.close();
  }
}
