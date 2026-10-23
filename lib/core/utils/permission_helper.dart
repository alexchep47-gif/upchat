import 'package:permission_handler/permission_handler.dart';

/// Aide à la demande des permissions nécessaires à UpChat
class PermissionHelper {
  /// Demande toutes les permissions critiques
  static Future<bool> requestAll() async {
    final statuses = await [
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

    // On considère OK si les permissions essentielles sont accordées
    final essential = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    return essential.every((p) => statuses[p]?.isGranted ?? false);
  }

  /// Vérifie si les permissions Bluetooth + Location sont OK
  static Future<bool> hasNearbyPermissions() async {
    return await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted &&
        await Permission.locationWhenInUse.isGranted;
  }
}
