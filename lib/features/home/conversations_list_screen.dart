import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/empty_state.dart';

/// Liste des discussions (style WhatsApp)
class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  @override
  void initState() {
    super.initState();
    // Démarre la découverte P2P au lancement de l'écran principal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NearbyProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final nearby = context.watch<NearbyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UpChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: recherche de discussions
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'group':
                  Navigator.pushNamed(context, AppRouter.createGroup);
                  break;
                case 'profile':
                  Navigator.pushNamed(context, AppRouter.profile);
                  break;
                case 'settings':
                  Navigator.pushNamed(context, AppRouter.settings);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'group', child: Text('Nouveau groupe')),
              const PopupMenuItem(value: 'profile', child: Text('Profil')),
              const PopupMenuItem(value: 'settings', child: Text('Réglages')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de statut Nearby
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: nearby.isDiscovering
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  nearby.isDiscovering ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                  size: 18,
                  color: nearby.isDiscovering ? AppColors.accent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nearby.isDiscovering
                        ? 'Recherche d\'appareils UpChat… (${nearby.nearbyDevices.length} trouvé(s))'
                        : 'Découverte arrêtée',
                    style: TextStyle(
                      fontSize: 13,
                      color: nearby.isDiscovering ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des conversations (vide pour l'instant)
          Expanded(
            child: nearby.nearbyDevices.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucune discussion',
                    subtitle: 'Approche-toi d\'autres téléphones UpChat pour commencer à chatter hors ligne.',
                  )
                : ListView.builder(
                    itemCount: nearby.nearbyDevices.length,
                    itemBuilder: (context, index) {
                      final device = nearby.nearbyDevices[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (device['name'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(device['name'] as String? ?? 'Inconnu'),
                        subtitle: const Text('Appareil à proximité'),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRouter.chat,
                            arguments: {
                              'conversationId': device['endpointId'],
                              'peerName': device['name'] ?? 'Contact',
                              'peerId': device['endpointId'],
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: ouvrir sélecteur de contacts proches
        },
        child: const Icon(Icons.message_rounded),
      ),
    );
  }
}
