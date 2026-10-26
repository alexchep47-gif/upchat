import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../features/stories/stories_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/glass_container.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        final started = await context.read<NearbyProvider>().start();
        if (!started && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Active le Bluetooth et autorise la proximité pour découvrir des contacts.'),
            ),
          );
        }
      }
    });
  }

  void _openNewChat() {
    Navigator.pushNamed(context, AppRouter.addContactByPhone);
  }

  void _openProfile() {
    Navigator.pushNamed(context, AppRouter.profile);
  }

  void _openSettings() {
    Navigator.pushNamed(context, AppRouter.settings);
  }

  void _showNearbyStatus() {
    final nearby = context.read<NearbyProvider>();
    final message = nearby.nearbyDevices.isEmpty
        ? 'Aucun appareil proche pour le moment.'
        : '${nearby.nearbyDevices.length} appareil(s) proche(s) disponible(s).';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();
    final chat = context.watch<ChatProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final peopleCount = chat.conversations.where((c) => !c.isGroup).length;
    final groupCount = chat.conversations.where((c) => c.isGroup).length;
    final nearbyCount = nearby.nearbyDevices.length;
    final hasContent = chat.conversations.isNotEmpty || nearbyCount > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final contentWidth = constraints.maxWidth >= 900
                        ? 760.0
                        : constraints.maxWidth;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: contentWidth,
                        height: constraints.maxHeight,
                        child: CustomScrollView(
                          slivers: [
                      SliverToBoxAdapter(
                        child: _HomeHeader(
                          onProfile: _openProfile,
                          onNearby: _showNearbyStatus,
                          onNewChat: _openNewChat,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _ConversationTabs(
                          selectedIndex: _selectedTab,
                          peopleCount: peopleCount,
                          groupCount: groupCount,
                          nearbyCount: nearbyCount,
                          onChanged: (index) =>
                              setState(() => _selectedTab = index),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _InfoBanner(
                          connectivity: connectivity,
                          nearby: nearby,
                        ),
                      ),
                      const SliverToBoxAdapter(child: StoriesBar()),
                      if (!hasContent)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyConversationState(onNewChat: _openNewChat),
                        )
                      else
                        _ConversationSliver(
                          nearby: nearby,
                          chat: chat,
                          selectedTab: _selectedTab,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 92)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _BottomNavigation(
                      selectedIndex: 2,
                      onProfile: _openProfile,
                      onNearby: _showNearbyStatus,
                      onHome: () => setState(() => _selectedTab = 0),
                      onSettings: _openSettings,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onNearby;
  final VoidCallback onNewChat;

  const _HomeHeader({
    required this.onProfile,
    required this.onNearby,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Modifier'),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Échanges',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          _HeaderIconButton(
            icon: Icons.radar_rounded,
            tooltip: 'Appareils proches',
            onPressed: onNearby,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.edit_square,
            tooltip: 'Nouvelle discussion',
            onPressed: onNewChat,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 25),
        color: Theme.of(context).colorScheme.onSurface,
        style: IconButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.18)),
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(11),
        ),
      ),
    );
  }
}

class _ConversationTabs extends StatelessWidget {
  final int selectedIndex;
  final int peopleCount;
  final int groupCount;
  final int nearbyCount;
  final ValueChanged<int> onChanged;

  const _ConversationTabs({
    required this.selectedIndex,
    required this.peopleCount,
    required this.groupCount,
    required this.nearbyCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const _TabData('Tous'),
      _TabData('Personnel', peopleCount),
      _TabData('Groupes', groupCount),
      _TabData('Proches', nearbyCount),
    ];

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      blur: 16,
      opacity: Theme.of(context).brightness == Brightness.dark ? .42 : .72,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.primary.withOpacity(0.20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          tabs[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: selectedIndex == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (tabs[i].count != null && tabs[i].count! > 0) ...[
                        const SizedBox(width: 5),
                        _CountBadge(value: tabs[i].count!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabData {
  final String label;
  final int? count;

  const _TabData(this.label, [this.count]);
}

class _CountBadge extends StatelessWidget {
  final int value;

  const _CountBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final ConnectivityProvider connectivity;
  final NearbyProvider nearby;

  const _InfoBanner({
    required this.connectivity,
    required this.nearby,
  });

  @override
  Widget build(BuildContext context) {
    final internetEnabled = connectivity.internetModeEnabled;
    final title = internetEnabled && connectivity.isOnline
        ? 'Mode internet actif'
        : internetEnabled
            ? 'Mode internet activé — en attente'
        : nearby.isRunning
            ? 'Appareils proches disponibles'
            : 'Mode internet inactif';
    final subtitle = internetEnabled && connectivity.isOnline
        ? 'Les contacts peuvent être trouvés par numéro.'
        : internetEnabled
            ? 'Le réseau sera utilisé dès qu’il sera disponible.'
        : nearby.isRunning
            ? '${nearby.nearbyDevices.length} appareil(s) détecté(s) autour de vous.'
            : 'Les discussions restent en mode local.';

    return GlassContainer(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      blur: 16,
      opacity: Theme.of(context).brightness == Brightness.dark ? .54 : .76,
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
      child: Row(
        children: [
          Icon(
            internetEnabled && connectivity.isOnline
                ? Icons.public_rounded
                : Icons.wifi_tethering_rounded,
            color: AppColors.primary,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            internetEnabled && connectivity.isOnline
                ? Icons.check_circle_rounded
                : internetEnabled
                    ? Icons.schedule_rounded
                    : Icons.cloud_off_rounded,
            color: internetEnabled && connectivity.isOnline
                ? AppColors.primary
                : internetEnabled
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 21,
          ),
        ],
      ),
    );
  }
}

class _ConversationSliver extends StatelessWidget {
  final NearbyProvider nearby;
  final ChatProvider chat;
  final int selectedTab;

  const _ConversationSliver({
    required this.nearby,
    required this.chat,
    required this.selectedTab,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <Widget>[];
    final showNearby = selectedTab == 0 || selectedTab == 3;
    final showPeople = selectedTab == 0 || selectedTab == 1;
    final showGroups = selectedTab == 0 || selectedTab == 2;

    if (showNearby && !kIsWeb) {
      for (final device in nearby.nearbyDevices) {
        entries.add(
          _ConversationTile(
            title: device.name,
            subtitle: 'En ligne · à proximité',
            status: 'maintenant',
            isOnline: true,
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
          ),
        );
      }
    }

    for (final conv in chat.conversations) {
      if (conv.isGroup && !showGroups) continue;
      if (!conv.isGroup && !showPeople) continue;
      entries.add(
        _ConversationTile(
          title: conv.title,
          subtitle: conv.lastMessage ?? 'Aucune activité récente',
          status: conv.lastMessageAt == null
              ? ''
              : DateFormat('HH:mm').format(conv.lastMessageAt!),
          unread: conv.unreadCount,
          isGroup: conv.isGroup,
          photoPath: conv.photoPath,
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
        ),
      );
    }

    if (entries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Aucune discussion dans cette catégorie',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate(entries),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final int unread;
  final bool isOnline;
  final bool isGroup;
  final String? photoPath;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.unread = 0,
    this.isOnline = false,
    this.isGroup = false,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.09)),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(
                    name: title,
                    photoPath: photoPath,
                    radius: 27,
                  ),
                  if (isOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (status.isNotEmpty)
                          Text(
                            status,
                            style: TextStyle(
                              color: unread > 0
                                  ? AppColors.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isGroup) ...[
                          Icon(
                            Icons.group_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          _CountBadge(value: unread),
                        ],
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

class _EmptyConversationState extends StatelessWidget {
  final VoidCallback onNewChat;

  const _EmptyConversationState({required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(
            icon: Icons.forum_outlined,
            title: 'Aucune discussion',
            subtitle: 'Démarre une conversation avec un contact.',
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.edit_square),
            label: const Text('Démarrer une discussion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onProfile;
  final VoidCallback onNearby;
  final VoidCallback onHome;
  final VoidCallback onSettings;

  const _BottomNavigation({
    required this.selectedIndex,
    required this.onProfile,
    required this.onNearby,
    required this.onHome,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _BottomItem(Icons.people_alt_outlined, 'Contacts', onProfile),
      _BottomItem(Icons.call_outlined, 'Proximité', onNearby),
      _BottomItem(Icons.forum_rounded, 'Échanges', onHome),
      _BottomItem(Icons.settings_outlined, 'Réglages', onSettings),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassContainer(
          blur: 22,
          opacity: Theme.of(context).brightness == Brightness.dark ? .72 : .82,
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavigationItem(
                    item: items[i],
                    selected: selectedIndex == i,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomItem(this.icon, this.label, this.onTap);
}

class _BottomNavigationItem extends StatelessWidget {
  final _BottomItem item;
  final bool selected;

  const _BottomNavigationItem({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.onSurface.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 24,
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
