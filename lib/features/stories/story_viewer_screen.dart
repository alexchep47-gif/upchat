import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/story_model.dart';
import '../../data/services/storage_service.dart';
import '../../providers/stories_provider.dart';

/// Visualisation des stories avec barre de progression
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
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stories = context.read<StoriesProvider>().storiesForUser(widget.userId);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _stories.isEmpty ? 0 : _stories.length - 1,
    );
    _startProgress();

    if (_stories.isNotEmpty) {
      context.read<StoriesProvider>().markViewed(
        _stories[_currentIndex].id,
        StorageService.userId,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    _timer?.cancel();
    _progress = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.05 / 5;
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
      context.read<StoriesProvider>().markViewed(
        _stories[_currentIndex].id,
        StorageService.userId,
      );
      _startProgress();
    } else {
      Navigator.pop(context);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progress = 0;
      });
      _startProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Aucune story',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final story = _stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previous();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (story.type == StoryType.image && story.mediaPath != null && !kIsWeb)
              Image.file(File(story.mediaPath!), fit: BoxFit.contain)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    story.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(_stories.length, (index) {
                  final active = index <= _currentIndex;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(
                        right: index < _stories.length - 1 ? 4 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Text(
                story.userName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
