import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/chat_provider.dart';
import '../../features/stories/stories_bar.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NearbyProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('UpChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'group':
                  Navigator.pushNamed(context, AppRouter.createGroup);
                  break;
                case 'story':
                  Navigator.pushNamed(context, AppRouter.createStory);
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
              const PopupMenuItem(value: 'story', child: Text('Nouvelle story')),
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
            color: nearby.isRunning
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  nearby.isRunning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                  size: 18,
                  color: nearby.isRunning ? AppColors.accent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nearby.isRunning
                        ? 'Recherche… ${nearby.nearbyDevices.length} appareil(s) trouvé(s)'
                        : 'Découverte arrêtée',
                    style: TextStyle(
                      fontSize: 13,
                      color: nearby.isRunning ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stories
          const StoriesBar(),

          const Divider(height: 1),

          Expanded(
            child: chat.conversations.isEmpty && nearby.nearbyDevices.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Aucune discussion',
                    subtitle:
                        'Approche-toi d\'autres téléphones UpChat pour commencer à chatter hors ligne.',
                  )
                : ListView(
                    children: [
                      // Appareils à proximité
                      if (nearby.nearbyDevices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            'À proximité',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...nearby.nearbyDevices.map((device) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                device.name.isNotEmpty ? device.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(device.name),
                            subtitle: const Text('Appareil UpChat à proximité'),
                            trailing: const Icon(Icons.circle, size: 10, color: AppColors.online),
                            onTap: () {
                              final conv = context.read<ChatProvider>().getOrCreateConversation(
                                    peerId: device.id,
                                    peerName: device.name,
                                    endpointId: device.endpointId,
                                  );
                              Navigator.pushNamed(
                                context,
                                AppRouter.chat,
                                arguments: {
                                  'conversationId': conv.id,
                                  'peerName': device.name,
                                  'peerId': device.id,
                                },
                              );
                            },
                          );
                        }),
                        const Divider(),
                      ],

                      // Conversations existantes
                      ...chat.conversations.map((conv) {
                        final time = conv.lastMessageAt != null
                            ? DateFormat('HH:mm').format(conv.lastMessageAt!)
                            : '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              conv.title.isNotEmpty ? conv.title[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(conv.title),
                          subtitle: Text(
                            conv.lastMessage ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (conv.unreadCount > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${conv.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRouter.chat,
                              arguments: {
                                'conversationId': conv.id,
                                'peerName': conv.title,
                                'peerId': conv.id,
                              },
                            );
                          },
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRouter.createStory);
        },
        child: const Icon(Icons.camera_alt_rounded),
      ),
    );
  }
}
