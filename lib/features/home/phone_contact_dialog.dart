import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../data/services/contact_directory_service.dart';
import '../../providers/chat_provider.dart';

class PhoneContactDialog extends StatefulWidget {
  const PhoneContactDialog({super.key});

  @override
  State<PhoneContactDialog> createState() => _PhoneContactDialogState();
}

class _PhoneContactDialogState extends State<PhoneContactDialog> {
  final _controller = TextEditingController();
  final _directory = ContactDirectoryService();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openChat() {
    final user = _directory.findByPhone(_controller.text);
    if (user == null) {
      setState(() => _error = 'Aucun utilisateur enregistré avec ce numéro.');
      return;
    }
    final conversation = context.read<ChatProvider>().getOrCreateConversation(
          peerId: user.id,
          peerName: user.name,
          endpointId: user.endpointId,
        );
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRouter.chat, arguments: {
      'conversationId': conversation.id,
      'peerName': user.name,
      'peerId': user.id,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Écrire à un numéro'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _openChat(),
        decoration: InputDecoration(
          labelText: 'Numéro de téléphone',
          hintText: '+237 6 00 00 00 00',
          errorText: _error,
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _openChat, child: const Text('Ouvrir')),
      ],
    );
  }
}
