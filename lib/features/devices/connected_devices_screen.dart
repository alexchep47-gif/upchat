import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/nearby_provider.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final devices = nearby.nearbyDevices;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appareils connectés'),
        actions: [
          IconButton(
            tooltip: 'Actualiser la découverte',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: nearby.start,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.primary.withOpacity(.14),
                    child: const Icon(Icons.devices_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Gérez les sessions actives et les appareils UpChat à proximité.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatusCard(
            icon: connectivity.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            title: connectivity.isOnline ? 'Relais internet actif' : 'Relais internet inactif',
            subtitle: connectivity.internetModeEnabled
                ? 'La présence et les messages peuvent être relayés.'
                : 'Active le mode internet dans Réglages pour synchroniser.',
            color: connectivity.isOnline ? AppColors.online : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          _StatusCard(
            icon: nearby.isRunning ? Icons.wifi_tethering_rounded : Icons.bluetooth_disabled_rounded,
            title: nearby.isRunning ? 'Découverte de proximité active' : 'Découverte de proximité arrêtée',
            subtitle: nearby.isRunning
                ? '${devices.length} appareil(s) trouvé(s) à portée.'
                : 'Bluetooth et Wi‑Fi Direct restent disponibles hors ligne.',
            color: nearby.isRunning ? AppColors.primary : AppColors.textSecondaryLight,
            action: nearby.isRunning
                ? TextButton(onPressed: nearby.stop, child: const Text('Arrêter'))
                : FilledButton.tonalIcon(
                    onPressed: nearby.start,
                    icon: const Icon(Icons.radar_rounded),
                    label: const Text('Démarrer'),
                  ),
          ),
          const SizedBox(height: 22),
          Text('À proximité', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(Icons.devices_other_rounded, size: 36, color: AppColors.primary),
                    SizedBox(height: 10),
                    Text('Aucun appareil connecté', textAlign: TextAlign.center),
                    SizedBox(height: 4),
                    Text('Les appareils UpChat apparaîtront ici lorsqu’ils seront à portée.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ...devices.map((device) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(.12),
                      child: const Icon(Icons.smartphone_rounded, color: AppColors.primary),
                    ),
                    title: Text(device.name),
                    subtitle: Text(nearby.connectedEndpoints.containsValue(device.id) ? 'Connecté' : 'Découvert'),
                    trailing: nearby.connectedEndpoints.containsValue(device.id)
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.online)
                        : const Icon(Icons.radio_button_unchecked_rounded),
                  ),
                )),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? action;
  const _StatusCard({required this.icon, required this.title, required this.subtitle, required this.color, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: color.withOpacity(.14), child: Icon(icon, color: color)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: action,
      ),
    );
  }
}
