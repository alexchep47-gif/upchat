import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/profile_provider.dart';
import '../../features/stories/stories_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/profile_avatar.dart';

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
    final connectivity = context.watch<ConnectivityProvider>();
    final profile = context.watch<ProfileProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 0,
            title: const Text('UpChat'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRouter.profile),
                  child: ProfileAvatar(
                    name: profile.name,
                    photoPath: profile.photoPath,
                    radius: 16,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'group':
                      Navigator.pushNamed(context, AppRouter.createGroup);
                      break;
                    case 'story':
                      Navigator.pushNamed(context, AppRouter.createStory);
                      break;
                    case 'settings':
                      Navigator.pushNamed(context, AppRouter.settings);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'story', child: Text('📖 Nouvelle story')),
                  const PopupMenuItem(value: 'group', child: Text('👥 Nouveau groupe')),
                  const PopupMenuItem(value: 'settings', child: Text('⚙️ Réglages')),
                ],
              ),
            ],
          ),

          // Status glass bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: (connectivity.isHybridReady
                              ? Colors.blue
                              : nearby.isRunning
                                  ? AppColors.accent
                                  : Colors.grey)
                          .withOpacity(isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(isDark ? 0.06 : 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          connectivity.isHybridReady
                              ? '🌐'
                              : nearby.isRunning
                                  ? '📡'
                                  : '💤',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            connectivity.isHybridReady
                                ? 'Mode hybride — local + internet'
                                : nearby.isRunning
                                    ? 'Offline — ${nearby.nearbyDevices.length} appareil(s) proche(s)'
                                    : connectivity.statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: StoriesBar()),

          if (chat.conversations.isEmpty && nearby.nearbyDevices.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Aucune discussion 💬',
                subtitle:
                    'Approche-toi d\'autres téléphones UpChat\nou active le mode internet dans Réglages.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                if (nearby.nearbyDevices.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'À proximité ✨',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  ...nearby.nearbyDevices.map((device) {
                    return _ConversationTile(
                      title: device.name,
                      subtitle: '🟢 En ligne · à proximité',
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
                  const Divider(height: 24),
                ],
                ...chat.conversations.map((conv) {
                  final time = conv.lastMessageAt != null
                      ? DateFormat('HH:mm').format(conv.lastMessageAt!)
                      : '';
                  return _ConversationTile(
                    title: conv.title,
                    subtitle: conv.lastMessage ?? '',
                    time: time,
                    unread: conv.unreadCount,
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
                const SizedBox(height: 88),
              ]),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRouter.createStory),
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Story'),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final int unread;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.title,
    required this.subtitle,
    this.time = '',
    this.unread = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                child: Text(
                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: unread > 0
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                              fontWeight:
                                  unread > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
