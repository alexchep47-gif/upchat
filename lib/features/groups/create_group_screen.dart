import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/group_model.dart';
import '../../data/models/conversation_model.dart';
import '../../data/services/storage_service.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/chat_provider.dart';
import '../../core/routes/app_router.dart';

/// Création d'un groupe offline
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne un nom au groupe')),
      );
      return;
    }

    setState(() => _creating = true);

    final groupId = const Uuid().v4();
    final memberIds = [StorageService.userId, ..._selectedIds];

    final group = GroupModel(
      id: groupId,
      name: name,
      createdBy: StorageService.userId,
      memberIds: memberIds,
    );

    await StorageService.groups.put(groupId, group.toMap());

    // Crée aussi une conversation de type groupe
    final conv = ConversationModel(
      id: groupId,
      title: name,
      isGroup: true,
      participantIds: memberIds,
    );
    await StorageService.conversations.put(groupId, conv.toMap());

    // Recharge le ChatProvider
    // (simple : on notifie)
    if (mounted) {
      context.read<ChatProvider>(); // force rebuild plus tard
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Groupe "$name" créé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearby = context.watch<NearbyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau groupe'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: Text(
              _creating ? '…' : 'Créer',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                prefixIcon: Icon(Icons.group),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Membres à proximité',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: nearby.nearbyDevices.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun appareil UpChat à proximité.\nTu pourras ajouter des membres plus tard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: nearby.nearbyDevices.length,
                    itemBuilder: (context, index) {
                      final device = nearby.nearbyDevices[index];
                      final selected = _selectedIds.contains(device.id);
                      return CheckboxListTile(
                        value: selected,
                        activeColor: AppColors.accent,
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            device.name.isNotEmpty ? device.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(device.name),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedIds.add(device.id);
                            } else {
                              _selectedIds.remove(device.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
