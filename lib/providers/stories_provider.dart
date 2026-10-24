import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/story_model.dart';
import '../data/services/storage_service.dart';
import '../data/services/nearby_service.dart';

/// Gère les stories offline (création, stockage, diffusion)
class StoriesProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();
  final NearbyService _nearby = NearbyService();

  final List<StoryModel> _stories = [];

  List<StoryModel> get stories => List.unmodifiable(_stories);

  /// Stories groupées par utilisateur (non expirées)
  Map<String, List<StoryModel>> get storiesByUser {
    final map = <String, List<StoryModel>>{};
    for (final s in _stories.where((s) => !s.isExpired)) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }

  List<StoryModel> storiesForUser(String userId) {
    return _stories
        .where((s) => s.userId == userId && !s.isExpired)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  StoriesProvider() {
    _load();
  }

  void _load() {
    for (final key in StorageService.stories.keys) {
      final map = StorageService.stories.get(key);
      if (map is Map) {
        final story = StoryModel.fromMap(Map<String, dynamic>.from(map));
        if (!story.isExpired) {
          _stories.add(story);
        } else {
          // Nettoie les expirées
          StorageService.stories.delete(key);
        }
      }
    }
    notifyListeners();
  }

  /// Crée une story texte ou média
  Future<void> createStory({
    required StoryType type,
    required String content,
    String? mediaPath,
  }) async {
    final story = StoryModel(
      id: _uuid.v4(),
      userId: StorageService.userId,
      userName: StorageService.userName,
      type: type,
      content: content,
      mediaPath: mediaPath,
    );

    _stories.add(story);
    await StorageService.stories.put(story.id, story.toMap());
    notifyListeners();

    // Diffuse aux contacts à proximité (texte pour l'instant)
    await _nearby.broadcastText(
      conversationId: 'story_${story.id}',
      text: '📖 Story: ${story.content}',
    );
  }

  void markViewed(String storyId, String viewerId) {
    final index = _stories.indexWhere((s) => s.id == storyId);
    if (index == -1) return;

    final story = _stories[index];
    if (story.viewedBy.contains(viewerId)) return;

    final updated = StoryModel(
      id: story.id,
      userId: story.userId,
      userName: story.userName,
      type: story.type,
      content: story.content,
      mediaPath: story.mediaPath,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      viewedBy: [...story.viewedBy, viewerId],
      comments: story.comments,
    );

    _stories[index] = updated;
    StorageService.stories.put(storyId, updated.toMap());
    notifyListeners();
  }

  Future<bool> addComment({
    required String storyId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final index = _stories.indexWhere((story) => story.id == storyId);
    if (index == -1 || _stories[index].isExpired) return false;

    final story = _stories[index];
    final comment = StoryComment(
      id: _uuid.v4(),
      userId: StorageService.userId,
      userName: StorageService.userName,
      text: trimmed,
    );
    final updated = StoryModel(
      id: story.id,
      userId: story.userId,
      userName: story.userName,
      type: story.type,
      content: story.content,
      mediaPath: story.mediaPath,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      viewedBy: story.viewedBy,
      comments: [...story.comments, comment],
    );

    _stories[index] = updated;
    await StorageService.stories.put(story.id, updated.toMap());
    notifyListeners();

    await _nearby.broadcastText(
      conversationId: 'story_${story.id}',
      text: '💬 ${StorageService.userName}: $trimmed',
    );
    return true;
  }
}
