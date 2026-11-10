import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'storage_service.dart';

const _signalPrefix = 'signal_v1_';

/// Enveloppe transportable par BLE, Nearby ou WebSocket.
/// Le relais ne reçoit jamais de texte clair : uniquement [ciphertext].
class SignalEnvelope {
  const SignalEnvelope({
    required this.messageId,
    required this.senderId,
    required this.recipientId,
    required this.ciphertext,
    required this.preKeyMessage,
  });

  final String messageId;
  final String senderId;
  final String recipientId;
  final String ciphertext;
  final bool preKeyMessage;

  Map<String, dynamic> toMap() => {
        'protocol': 'upchat.signal.v1',
        'messageId': messageId,
        'senderId': senderId,
        'recipientId': recipientId,
        'ciphertext': ciphertext,
        'preKeyMessage': preKeyMessage,
      };

  factory SignalEnvelope.fromMap(Map<String, dynamic> map) {
    final ciphertext = map['ciphertext'];
    if (ciphertext is! String || ciphertext.isEmpty) {
      throw const FormatException('Signal envelope without ciphertext');
    }
    return SignalEnvelope(
      messageId: map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      recipientId: map['recipientId'] as String? ?? '',
      ciphertext: ciphertext,
      preKeyMessage: map['preKeyMessage'] == true,
    );
  }
}

/// Signal Protocol v3 : X3DH + Double Ratchet.
///
/// Les clés d’identité, pré-clés et sessions sont stockées dans la box Hive
/// chiffrée ouverte par StorageService. Le serveur ne reçoit que le bundle
/// public et des messages Signal sérialisés.
class SignalCryptoService {
  static final SignalCryptoService instance = SignalCryptoService._();
  SignalCryptoService._();

  late final _HiveSignalStore _store;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _store = _HiveSignalStore(StorageService.users);
    await _store.initialize();
    _initialized = true;
  }

  Future<Map<String, dynamic>> publicPreKeyBundle() async {
    await init();
    final preKey = await _store.firstPreKey();
    final signed = await _store.loadSignedPreKey(_store.signedPreKeyId);
    final identity = await _store.getIdentityKeyPair();
    return {
      'protocol': 'upchat.signal.v1',
      'userId': StorageService.userId,
      'deviceId': 1,
      'registrationId': await _store.getLocalRegistrationId(),
      'identityKey': base64Encode(identity.getPublicKey().serialize()),
      'preKeyId': preKey.id,
      'preKey': base64Encode(preKey.getKeyPair().publicKey.serialize()),
      'signedPreKeyId': _store.signedPreKeyId,
      'signedPreKey': base64Encode(
        signed.getKeyPair().publicKey.serialize(),
      ),
      'signedPreKeySignature': base64Encode(signed.signature),
    };
  }

  Future<void> trustBundle({
    required String remoteUserId,
    required Map<String, dynamic> bundle,
  }) async {
    await init();
    if (bundle['protocol'] != 'upchat.signal.v1') {
      throw const FormatException('Unsupported Signal bundle');
    }
    final address = SignalProtocolAddress(remoteUserId, 1);
    final preKey = bundle['preKey'];
    final preKeyId = bundle['preKeyId'];
    final signedPreKey = bundle['signedPreKey'];
    final signedPreKeyId = bundle['signedPreKeyId'];
    final identityKey = bundle['identityKey'];
    final signature = bundle['signedPreKeySignature'];
    if (preKey is! String || preKeyId is! int || signedPreKey is! String ||
        signedPreKeyId is! int || identityKey is! String || signature is! String) {
      throw const FormatException('Incomplete Signal bundle');
    }
    final parsed = PreKeyBundle(
      (bundle['registrationId'] as num?)?.toInt() ?? 0,
      (bundle['deviceId'] as num?)?.toInt() ?? 1,
      preKeyId,
      Curve.decodePoint(base64Decode(preKey), 0),
      signedPreKeyId,
      Curve.decodePoint(base64Decode(signedPreKey), 0),
      Uint8List.fromList(base64Decode(signature)),
      IdentityKey.fromBytes(Uint8List.fromList(base64Decode(identityKey)), 0),
    );
    final builder = SessionBuilder.fromSignalStore(_store, address);
    await builder.processPreKeyBundle(parsed);
  }

  Future<SignalEnvelope> encrypt({
    required String remoteUserId,
    required String messageId,
    required String plaintext,
  }) async {
    await init();
    if (plaintext.isEmpty) throw const FormatException('Empty plaintext');
    final address = SignalProtocolAddress(remoteUserId, 1);
    final cipher = SessionCipher.fromStore(_store, address);
    final encrypted = await cipher.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    final bytes = encrypted.serialize();
    return SignalEnvelope(
      messageId: messageId,
      senderId: StorageService.userId,
      recipientId: remoteUserId,
      ciphertext: base64Encode(bytes),
      preKeyMessage: encrypted.getType() == CiphertextMessage.prekeyType,
    );
  }

  Future<String> decrypt(SignalEnvelope envelope) async {
    await init();
    if (envelope.recipientId.isNotEmpty &&
        envelope.recipientId != StorageService.userId) {
      throw const FormatException('Signal envelope recipient mismatch');
    }
    final address = SignalProtocolAddress(envelope.senderId, 1);
    final cipher = SessionCipher.fromStore(_store, address);
    final bytes = Uint8List.fromList(base64Decode(envelope.ciphertext));
    final plaintext = envelope.preKeyMessage
        ? await cipher.decrypt(PreKeySignalMessage(bytes))
        : await cipher.decryptFromSignal(SignalMessage.fromSerialized(bytes));
    return utf8.decode(plaintext);
  }
}

class _HiveSignalStore implements SignalProtocolStore {
  _HiveSignalStore(this.box);
  final dynamic box;
  late IdentityKeyPair _identity;
  late int registrationId;
  late final int signedPreKeyId;

  String _key(String suffix) => '$_signalPrefix$suffix';

  Future<void> initialize() async {
    final identityBytes = box.get(_key('identity'));
    if (identityBytes is Uint8List || identityBytes is List<int>) {
      _identity = IdentityKeyPair.fromSerialized(Uint8List.fromList(List<int>.from(identityBytes)));
      registrationId = (box.get(_key('registration')) as num).toInt();
      signedPreKeyId = (box.get(_key('signed_id')) as num).toInt();
      return;
    }
    _identity = generateIdentityKeyPair();
    registrationId = generateRegistrationId(false);
    signedPreKeyId = 1;
    await box.put(_key('identity'), _identity.serialize());
    await box.put(_key('registration'), registrationId);
    await box.put(_key('signed_id'), signedPreKeyId);
    for (final record in generatePreKeys(1, 100)) {
      await storePreKey(record.id, record);
    }
    await storeSignedPreKey(
      signedPreKeyId,
      generateSignedPreKey(_identity, signedPreKeyId),
    );
  }

  Future<PreKeyRecord> firstPreKey() async {
    for (var id = 1; id <= 100; id++) {
      if (await containsPreKey(id)) return loadPreKey(id);
    }
    final record = generatePreKeys(101, 1).first;
    await storePreKey(record.id, record);
    return record;
  }

  String _session(SignalProtocolAddress address) =>
      _key('session_${base64UrlEncode(utf8.encode(address.toString()))}');
  String _trusted(SignalProtocolAddress address) =>
      _key('trusted_${base64UrlEncode(utf8.encode(address.toString()))}');

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => _identity;
  @override
  Future<int> getLocalRegistrationId() async => registrationId;
  @override
  Future<bool> saveIdentity(SignalProtocolAddress address, IdentityKey? key) async {
    if (key == null) return false;
    final old = await getIdentity(address);
    await box.put(_trusted(address), key.serialize());
    return old == null || base64Encode(old.serialize()) != base64Encode(key.serialize());
  }
  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address, IdentityKey? key, Direction direction) async {
    if (key == null) return false;
    final old = await getIdentity(address);
    return old == null || base64Encode(old.serialize()) == base64Encode(key.serialize());
  }
  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final raw = box.get(_trusted(address));
    if (raw is! List) return null;
    return IdentityKey.fromBytes(Uint8List.fromList(List<int>.from(raw)), 0);
  }

  String _preKey(int id) => _key('pre_$id');
  @override
  Future<PreKeyRecord> loadPreKey(int id) async => PreKeyRecord.fromBuffer(Uint8List.fromList(List<int>.from(box.get(_preKey(id)))));
  @override
  Future<void> storePreKey(int id, PreKeyRecord record) async => box.put(_preKey(id), record.serialize());
  @override
  Future<bool> containsPreKey(int id) async => box.containsKey(_preKey(id));
  @override
  Future<void> removePreKey(int id) async => box.delete(_preKey(id));

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final raw = box.get(_session(address));
    return raw is List ? SessionRecord.fromSerialized(Uint8List.fromList(List<int>.from(raw))) : SessionRecord();
  }
  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async => box.put(_session(address), record.serialize());
  @override
  Future<bool> containsSession(SignalProtocolAddress address) async => box.containsKey(_session(address));
  @override
  Future<void> deleteSession(SignalProtocolAddress address) async => box.delete(_session(address));
  @override
  Future<void> deleteAllSessions(String name) async {
    for (final key in box.keys.where((k) => k.toString().startsWith(_key('session_'))).toList()) {
      final decoded = utf8.decode(base64Url.decode(key.toString().substring(_key('session_').length)));
      if (decoded.startsWith('$name:')) await box.delete(key);
    }
  }
  @override
  Future<List<int>> getSubDeviceSessions(String name) async => const [];

  String _signed(int id) => _key('signed_$id');
  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int id) async => SignedPreKeyRecord.fromSerialized(Uint8List.fromList(List<int>.from(box.get(_signed(id)))));
  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async => [await loadSignedPreKey(signedPreKeyId)];
  @override
  Future<void> storeSignedPreKey(int id, SignedPreKeyRecord record) async => box.put(_signed(id), record.serialize());
  @override
  Future<bool> containsSignedPreKey(int id) async => box.containsKey(_signed(id));
  @override
  Future<void> removeSignedPreKey(int id) async => box.delete(_signed(id));
}
