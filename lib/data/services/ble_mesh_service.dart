import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Transport BLE commun Android/iOS.
///
/// Le téléphone voisin expose le service UUID UpChat via une implémentation
/// périphérique compatible. Les paquets restent des enveloppes opaques ; ce
/// service ne chiffre et ne déchiffre jamais le contenu.
class BleMeshService {
  static final BleMeshService instance = BleMeshService._();
  BleMeshService._();

  static final Guid serviceUuid = Guid('7d5a0001-7b5e-4b1b-9d21-757043686174');
  static final Guid writeUuid = Guid('7d5a0002-7b5e-4b1b-9d21-757043686174');
  static final Guid notifyUuid = Guid('7d5a0003-7b5e-4b1b-9d21-757043686174');

  final _received = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<List<int>>? _notifySubscription;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  BluetoothCharacteristic? _notify;

  Stream<Map<String, dynamic>> get received => _received.stream;
  bool get isConnected => _device != null && _write != null;

  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 8)}) async {
    final results = <ScanResult>[];
    final sub = FlutterBluePlus.onScanResults.listen((items) {
      for (final item in items) {
        if (!results.any((r) => r.device.remoteId == item.device.remoteId)) {
          results.add(item);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: timeout,
      );
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      return results;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    await device.connect(timeout: const Duration(seconds: 12));
    final services = await device.discoverServices();
    final service = services.where((s) => s.uuid == serviceUuid).firstOrNull;
    if (service == null) {
      await device.disconnect();
      throw StateError('Ce périphérique ne propose pas le protocole UpChat BLE.');
    }
    _write = service.characteristics.where((c) => c.uuid == writeUuid).firstOrNull;
    _notify = service.characteristics.where((c) => c.uuid == notifyUuid).firstOrNull;
    if (_write == null || _notify == null) {
      await device.disconnect();
      throw StateError('Les caractéristiques BLE UpChat sont incomplètes.');
    }
    await _notify!.setNotifyValue(true);
    _notifySubscription = _notify!.lastValueStream.listen(_handlePacket);
    _device = device;
  }

  Future<void> sendOpaqueEnvelope(Map<String, dynamic> envelope) async {
    if (!isConnected) throw StateError('Aucune liaison BLE UpChat active.');
    if (envelope['ciphertext'] is! String) {
      throw StateError('Une enveloppe chiffrée est requise avant le relais BLE.');
    }
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode({
      'protocol': 'upchat.ble.v1',
      'type': 'relay',
      'envelope': envelope,
    })));
    if (bytes.length > 180) {
      throw StateError('Cette enveloppe dépasse la taille BLE actuelle. Utilise le relais internet.');
    }
    await _write!.write(bytes, withoutResponse: false);
  }

  void _handlePacket(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map && decoded['type'] == 'relay' && decoded['envelope'] is Map) {
        final envelope = Map<String, dynamic>.from(decoded['envelope'] as Map);
        if (envelope['ciphertext'] is String) _received.add(envelope);
      }
    } catch (_) {
      // Les paquets invalides sont rejetés sans exposer leur contenu.
    }
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    final device = _device;
    _device = null;
    _write = null;
    _notify = null;
    if (device != null) await device.disconnect();
  }

  Future<void> dispose() async {
    await disconnect();
    await _received.close();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
