import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Création d'un groupe offline
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau groupe'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: créer le groupe
              Navigator.pop(context);
            },
            child: const Text('Créer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Les membres seront ajoutés parmi les appareils UpChat à proximité.',
              style: TextStyle(color: Colors.grey),
            ),
            // TODO: liste des appareils proches à cocher
          ],
        ),
      ),
    );
  }
}
