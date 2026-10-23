import 'package:flutter/material.dart';

/// Gère les stories offline
class StoriesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _stories = [];

  List<Map<String, dynamic>> get stories => List.unmodifiable(_stories);

  List<Map<String, dynamic>> storiesForUser(String userId) {
    return _stories.where((s) => s['userId'] == userId).toList();
  }

  void loadStories() {
    // TODO: charger depuis Hive + filtrer les expirées (> 24h)
    notifyListeners();
  }

  void addStory(Map<String, dynamic> story) {
    _stories.add(story);
    notifyListeners();
  }
}
