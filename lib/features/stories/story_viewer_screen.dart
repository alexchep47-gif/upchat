import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/story_model.dart';
import '../../data/services/storage_service.dart';
import '../../providers/stories_provider.dart';

/// Visualisation des stories avec progression, navigation et commentaires.
class StoryViewerScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late List<StoryModel> _stories;
  late int _currentIndex;
  late final int _durationSeconds;
  late final bool _autoPlay;
  double _progress = 0;
  Timer? _timer;

  StoryModel get _currentStory => _stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _stories = context.read<StoriesProvider>().storiesForUser(widget.userId);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _stories.isEmpty ? 0 : _stories.length - 1,
    );
    _durationSeconds = StorageService.storyViewDuration.clamp(3, 30).toInt();
    _autoPlay = StorageService.autoPlayStories;

    if (_stories.isNotEmpty) {
      _markCurrentViewed();
      if (_autoPlay) _startProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _markCurrentViewed() {
    context.read<StoriesProvider>().markViewed(
          _currentStory.id,
          StorageService.userId,
        );
  }

  void _startProgress() {
    _timer?.cancel();
    if (!_autoPlay) return;
    _progress = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 0.05 / _durationSeconds;
        if (_progress >= 1) {
          _next();
        }
      });
    });
  }

  void _next() {
    if (_currentIndex < _stories.length - 1) {
      setState(() {
        _currentIndex++;
        _progress = 0;
      });
      _markCurrentViewed();
      _startProgress();
    } else {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progress = 0;
      });
      _markCurrentViewed();
      _startProgress();
    }
  }

  Future<void> _showComments() async {
    _timer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoryCommentsSheet(storyId: _currentStory.id),
    );
    if (mounted && _autoPlay) _startProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Cette story n’est plus disponible',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final story = _currentStory;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 3) {
                _previous();
              } else {
                _next();
              }
            },
            child: _StoryContent(story: story),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _ProgressBars(
              length: _stories.length,
              currentIndex: _currentIndex,
              progress: _progress,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 22,
            left: 16,
            right: 12,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    story.userName.isNotEmpty
                        ? story.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    story.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 18,
            child: _ReplyBar(
              commentCount: story.comments.length,
              onPressed: _showComments,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryContent extends StatelessWidget {
  final StoryModel story;

  const _StoryContent({required this.story});

  @override
  Widget build(BuildContext context) {
    if (story.type == StoryType.image && story.mediaPath != null && !kIsWeb) {
      return Image.file(File(story.mediaPath!), fit: BoxFit.contain);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          story.content,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  final int length;
  final int currentIndex;
  final double progress;

  const _ProgressBars({
    required this.length,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(length, (index) {
        final value = index < currentIndex
            ? 1.0
            : index == currentIndex
                ? progress
                : 0.0;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < length - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final int commentCount;
  final VoidCallback onPressed;

  const _ReplyBar({required this.commentCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              const Icon(Icons.reply_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Répondre à cette story…',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              if (commentCount > 0) ...[
                const Icon(Icons.mode_comment_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 5),
                Text(
                  '$commentCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCommentsSheet extends StatefulWidget {
  final String storyId;

  const _StoryCommentsSheet({required this.storyId});

  @override
  State<_StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<_StoryCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await context.read<StoriesProvider>().addComment(
          storyId: widget.storyId,
          text: _controller.text,
        );
    if (!mounted) return;
    if (sent) _controller.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Consumer<StoriesProvider>(
      builder: (context, provider, _) {
        final story = provider.stories.cast<StoryModel?>().firstWhere(
              (item) => item?.id == widget.storyId,
              orElse: () => null,
            );
        final comments = story?.comments ?? const <StoryComment>[];

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: const BoxDecoration(
              color: Color(0xFF17212B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Réponses à la story',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: comments.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                'Aucun commentaire pour le moment.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    comment.userName.isNotEmpty
                                        ? comment.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  comment.text,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Écrire un commentaire…',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
