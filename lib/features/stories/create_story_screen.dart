import 'package:flutter/material.dart';

/// Création d'une story (photo / vidéo / texte)
class CreateStoryScreen extends StatelessWidget {
  const CreateStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle story')),
      body: const Center(
        child: Text('Création de story — à implémenter'),
      ),
    );
  }
}
