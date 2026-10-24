import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../providers/stories_provider.dart';

class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final storiesProvider = context.watch<StoriesProvider>();
    final byUser = storiesProvider.storiesByUser;
    final myId = StorageService.userId;
    final hasMyStory = byUser.containsKey(myId);

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _StoryCircle(
            name: 'Ma story',
            hasStory: hasMyStory,
            isMe: true,
            onTap: () {
              if (hasMyStory) {
                Navigator.pushNamed(
                  context,
                  AppRouter.storyViewer,
                  arguments: {'userId': myId, 'initialIndex': 0},
                );
              } else {
                Navigator.pushNamed(context, AppRouter.createStory);
              }
            },
            onLongPress: () => Navigator.pushNamed(context, AppRouter.createStory),
          ),
          ...byUser.entries.where((e) => e.key != myId).map((entry) {
            final stories = entry.value;
            return _StoryCircle(
              name: stories.first.userName,
              hasStory: true,
              isMe: false,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRouter.storyViewer,
                  arguments: {'userId': entry.key, 'initialIndex': 0},
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  final String name;
  final bool hasStory;
  final bool isMe;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StoryCircle({
    required this.name,
    required this.hasStory,
    required this.isMe,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF2AABEE),
                          Color(0xFF25D366),
                          Color(0xFFFFB800),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: hasStory
                    ? null
                    : Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: isMe && !hasStory
                      ? const Icon(Icons.add_rounded, color: AppColors.primary)
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 68,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
