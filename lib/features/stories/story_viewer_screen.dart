import 'package:flutter/material.dart';

/// Visualisation des stories (barre de progression style WhatsApp)
class StoryViewerScreen extends StatelessWidget {
  final String userId;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Story de $userId — à implémenter',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
