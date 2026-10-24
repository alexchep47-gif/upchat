import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// État du Bluetooth fourni par le système, et non déduit seulement des permissions.
enum BluetoothAdapterState { enabled, disabled, unavailable, unknown }

class PermissionSnapshot {
  final bool bluetoothPermission;
  final bool locationPermission;
  final bool nearbyWifiPermission;
  final BluetoothAdapterState bluetoothState;
  final bool permanentlyDenied;

  const PermissionSnapshot({
    required this.bluetoothPermission,
    required this.locationPermission,
    required this.nearbyWifiPermission,
    required this.bluetoothState,
    required this.permanentlyDenied,
  });

  bool get isWeb => kIsWeb;
  bool get nearbyReady =>
      isWeb ||
      (bluetoothPermission &&
          locationPermission &&
          bluetoothState == BluetoothAdapterState.enabled);

  String get bluetoothLabel {
    switch (bluetoothState) {
      case BluetoothAdapterState.enabled:
        return 'Bluetooth activé';
      case BluetoothAdapterState.disabled:
        return 'Bluetooth désactivé';
      case BluetoothAdapterState.unavailable:
        return 'Bluetooth indisponible';
      case BluetoothAdapterState.unknown:
        return 'État Bluetooth inconnu';
    }
  }
}

class PermissionHelper {
  static const _deviceChannel = MethodChannel('upchat/device');

  static Future<PermissionSnapshot> readStatus() async {
    if (kIsWeb) {
      return const PermissionSnapshot(
        bluetoothPermission: true,
        locationPermission: true,
        nearbyWifiPermission: true,
        bluetoothState: BluetoothAdapterState.unavailable,
        permanentlyDenied: false,
      );
    }

    try {
      final bluetooth = await Permission.bluetoothConnect.status;
      final scan = await Permission.bluetoothScan.status;
      final location = await Permission.locationWhenInUse.status;
      final nearbyWifi = await Permission.nearbyWifiDevices.status;
      final stateName = await _deviceChannel.invokeMethod<String>('bluetoothState');
      final state = switch (stateName) {
        'enabled' => BluetoothAdapterState.enabled,
        'disabled' => BluetoothAdapterState.disabled,
        'unavailable' => BluetoothAdapterState.unavailable,
        _ => BluetoothAdapterState.unknown,
      };
      return PermissionSnapshot(
        bluetoothPermission: bluetooth.isGranted && scan.isGranted,
        locationPermission: location.isGranted,
        nearbyWifiPermission: nearbyWifi.isGranted,
        bluetoothState: state,
        permanentlyDenied: bluetooth.isPermanentlyDenied ||
            scan.isPermanentlyDenied ||
            location.isPermanentlyDenied,
      );
    } catch (error) {
      debugPrint('PermissionHelper.readStatus: $error');
      return const PermissionSnapshot(
        bluetoothPermission: false,
        locationPermission: false,
        nearbyWifiPermission: false,
        bluetoothState: BluetoothAdapterState.unknown,
        permanentlyDenied: false,
      );
    }
  }

  static Future<PermissionSnapshot> requestAllAndRead() async {
    if (!kIsWeb) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
        Permission.camera,
        Permission.microphone,
        Permission.photos,
        Permission.videos,
      ].request();
    }
    return readStatus();
  }

  /// Compatibilité avec les appels existants.
  static Future<bool> requestAll() async {
    final snapshot = await requestAllAndRead();
    return snapshot.nearbyReady;
  }

  static Future<bool> requestEnableBluetooth() async {
    if (kIsWeb) return true;
    try {
      return await _deviceChannel.invokeMethod<bool>('requestEnableBluetooth') ??
          false;
    } catch (error) {
      debugPrint('PermissionHelper.requestEnableBluetooth: $error');
      return false;
    }
  }

  static Future<bool> hasNearbyPermissions() async {
    final snapshot = await readStatus();
    return snapshot.bluetoothPermission && snapshot.locationPermission;
  }

  static Future<bool> openSettings() => openAppSettings();
}
