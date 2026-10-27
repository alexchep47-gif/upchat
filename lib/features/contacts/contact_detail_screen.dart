import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/glass_container.dart';

class ContactDetailScreen extends StatelessWidget {
  final String peerId;
  final String peerName;
  final String conversationId;

  const ContactDetailScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(conversationId);
    final lastAt = messages.isEmpty ? null : messages.last.createdAt;

    return Scaffold(
      backgroundColor: glass.chatGradientTop,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: glass.chatGradientTop.withOpacity(0.92),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                peerName,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.35),
                      glass.chatGradientTop,
                    ],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'avatar_$peerId',
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primary.withOpacity(0.25),
                      child: Text(
                        peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'à proximité · données locales',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Écrire',
                        onTap: () => Navigator.pop(context),
                      ),
                      _RoundAction(
                        icon: Icons.search_rounded,
                        label: 'Rechercher',
                        onTap: () => Navigator.pop(context, 'search'),
                      ),
                      _RoundAction(
                        icon: Icons.notifications_off_outlined,
                        label: 'Silence',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Préférence locale enregistrée'),
                            ),
                          );
                        },
                      ),
                      _RoundAction(
                        icon: Icons.lock_outline_rounded,
                        label: 'Verrouiller',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verrouillage local bientôt'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  GlassSurface(
                    borderRadius: BorderRadius.circular(18),
                    padding: const EdgeInsets.all(16),
                    blur: glass.blurChip,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Identifiant', value: peerId),
                        const Divider(height: 20),
                        _InfoRow(
                          label: 'Dernier échange',
                          value: lastAt == null
                              ? 'Aucun message'
                              : '${lastAt.day.toString().padLeft(2, '0')}/${lastAt.month.toString().padLeft(2, '0')}/${lastAt.year} '
                                  '${lastAt.hour.toString().padLeft(2, '0')}:${lastAt.minute.toString().padLeft(2, '0')}',
                        ),
                        const Divider(height: 20),
                        const _InfoRow(
                          label: 'Sécurité',
                          value:
                              'Conversation sécurisée — messages stockés sur cet appareil',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Médias partagés (local)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  GlassSurface(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(14),
                    blur: glass.blurChip,
                    child: Text(
                      '${messages.where((m) => m.mediaPath != null).length} fichier(s) dans cette conversation',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.tonal(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Effacer l’historique ?'),
                          content: const Text(
                              'Les messages seront supprimés de cet appareil.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Effacer'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await context
                            .read<ChatProvider>()
                            .clearConversationMessages(conversationId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('Effacer l’historique'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(28),
          blur: 14,
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    );
  }
}
