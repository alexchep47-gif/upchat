import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/internet_service.dart';
import '../../data/services/phone_directory_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';

/// Ajoute un contact par numéro de téléphone (mode internet).
class AddContactByPhoneScreen extends StatefulWidget {
  const AddContactByPhoneScreen({super.key});

  @override
  State<AddContactByPhoneScreen> createState() =>
      _AddContactByPhoneScreenState();
}

class _AddContactByPhoneScreenState extends State<AddContactByPhoneScreen> {
  final _phoneController = TextEditingController();
  final _internet = InternetService();
  final _directory = PhoneDirectoryService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Saisis un numéro de téléphone');
      return;
    }

    final myPhone = StorageService.userPhone;
    final normalized = StorageService.normalizePhone(raw);
    if (myPhone != null &&
        StorageService.normalizePhone(myPhone) == normalized) {
      setState(() => _error = 'C\'est ton propre numéro');
      return;
    }

    final connectivity = context.read<ConnectivityProvider>();
    if (!connectivity.internetModeEnabled) {
      setState(() => _error =
          'Active d\'abord le mode internet dans Réglages');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _internet.lookupByPhone(raw);
      if (!mounted) return;

      if (user == null) {
        setState(() {
          _loading = false;
          _error =
              'Aucun utilisateur UpChat trouvé pour ce numéro.\nIl doit avoir activé le mode internet et enregistré son numéro.';
        });
        return;
      }

      final conv = context.read<ChatProvider>().getOrCreateConversation(
            peerId: user.id,
            peerName: user.name,
          );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRouter.chat,
        arguments: {
          'conversationId': conv.id,
          'peerName': user.name,
          'peerId': user.id,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur réseau : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final known = _directory.all();
    final connectivity = context.watch<ConnectivityProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Contact par numéro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.phone_forwarded_rounded,
              size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'Ajouter un contact internet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            connectivity.internetModeEnabled
                ? 'Saisis le numéro enregistré par ton contact sur UpChat.'
                : 'Le mode internet est désactivé. Active-le dans Réglages pour utiliser cette fonction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '+237 6XX XXX XXX',
              prefixIcon: Icon(Icons.phone),
            ),
            onSubmitted: (_) => _search(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, height: 1.3),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading || !connectivity.internetModeEnabled
                  ? null
                  : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_loading ? 'Recherche…' : 'Rechercher'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          if (known.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'Contacts récents',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...known.map((u) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.15),
                  child: Text(
                    u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(u.name),
                subtitle: Text(u.phoneNumber ?? ''),
                onTap: () {
                  final conv =
                      context.read<ChatProvider>().getOrCreateConversation(
                            peerId: u.id,
                            peerName: u.name,
                          );
                  Navigator.pushNamed(
                    context,
                    AppRouter.chat,
                    arguments: {
                      'conversationId': conv.id,
                      'peerName': u.name,
                      'peerId': u.id,
                    },
                  );
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}
