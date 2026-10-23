import 'package:flutter/material.dart';

/// Gère les conversations et les messages
/// (logique complète à venir avec les modèles)
class ChatProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _conversations = [];
  final Map<String, List<Map<String, dynamic>>> _messages = {};

  List<Map<String, dynamic>> get conversations => List.unmodifiable(_conversations);

  List<Map<String, dynamic>> messagesFor(String conversationId) {
    return List.unmodifiable(_messages[conversationId] ?? []);
  }

  void loadConversations() {
    // TODO: charger depuis Hive
    notifyListeners();
  }

  void addMessage(String conversationId, Map<String, dynamic> message) {
    _messages.putIfAbsent(conversationId, () => []);
    _messages[conversationId]!.add(message);
    notifyListeners();
  }
}
