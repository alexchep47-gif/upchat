import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/user_model.dart';
import '../../data/services/internet_service.dart';
import '../../data/services/phone_directory_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/responsive_content.dart';

/// Nouvelle discussion par numéro — flux de contact rapide
///
/// 1. Saisie du numéro
/// 2. Lookup serveur si possible
/// 3. Sinon création d’une conversation locale liée au numéro
class AddContactByPhoneScreen extends StatefulWidget {
  const AddContactByPhoneScreen({super.key});

  @override
  State<AddContactByPhoneScreen> createState() =>
      _AddContactByPhoneScreenState();
}

class _AddContactByPhoneScreenState extends State<AddContactByPhoneScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _internet = InternetService();
  final _directory = PhoneDirectoryService();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connectivity = context.read<ConnectivityProvider>();
      if (!connectivity.internetModeEnabled) {
        await connectivity.setInternetMode(true);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Saisis un numéro de téléphone');
      return;
    }

    final normalized = StorageService.normalizePhone(raw);
    if (normalized.isEmpty || normalized.replaceAll('+', '').length < 8) {
      setState(() => _error = 'Numéro invalide');
      return;
    }

    final myPhone = StorageService.userPhone;
    if (myPhone != null &&
        StorageService.normalizePhone(myPhone) == normalized) {
      setState(() => _error = 'C’est ton propre numéro');
      return;
    }

    final profile = context.read<ProfileProvider>();
    if (profile.phoneNumber == null || profile.phoneNumber!.isEmpty) {
      setState(() {
        _error =
            'Enregistre d’abord ton numéro dans Profil.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      final user = await _internet.lookupByPhone(
        normalized,
        requireRegisteredAccount: true,
      );

      if (user == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error =
                'Aucun compte UpChat actif n’est associé à ce numéro.';
            _info =
                'Vérifie le numéro avec son indicatif pays ou demande à ton contact de créer un compte UpChat.';
          });
        }
        return;
      }

      UserModel resolvedUser = user;
      if (_nameController.text.trim().isNotEmpty &&
          (user.name == user.phoneNumber || user.name == normalized)) {
        resolvedUser = user.copyWith(name: _nameController.text.trim());
        await _directory.upsert(resolvedUser);
      }

      if (!mounted) return;

      final conv = context.read<ChatProvider>().getOrCreateConversation(
            peerId: resolvedUser.id,
            peerName: resolvedUser.name,
          );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRouter.chat,
            arguments: {
              'conversationId': conv.id,
              'peerName': resolvedUser.name,
              'peerId': resolvedUser.id,
            },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e is StateError
              ? e.message
              : 'Impossible de vérifier ce numéro pour le moment.';
          _info =
              'Vérifie ta connexion Internet et assure-toi que le serveur UpChat est disponible.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final hasMyPhone =
        profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle discussion'),
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.person_add_alt_1, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Par numéro de téléphone',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        kIsWeb
                            ? 'Sur le web, UpChat fonctionne par numéro de téléphone pour identifier le contact.'
                            : 'Mode internet : trouve un contact à distance par son numéro.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!hasMyPhone) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
                title: const Text('Ton numéro n’est pas enregistré'),
                subtitle: const Text(
                    'Indispensable pour que les autres puissent te trouver'),
                trailing: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.profile),
                  child: const Text('Profil'),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Connecté en tant que ${profile.phoneNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],

          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            autofocus: true,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '+237 6XX XXX XXX',
              prefixIcon: Icon(Icons.phone),
              helperText: 'Indicatif pays recommandé (ex. +237)',
            ),
            onSubmitted: (_) => _startChat(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Nom du contact (optionnel)',
              hintText: 'Comme dans ton carnet',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onSubmitted: (_) => _startChat(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, height: 1.3)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!,
                style: TextStyle(color: Colors.grey.shade700, height: 1.3)),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _startChat,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.chat_rounded),
              label: Text(_loading ? 'Ouverture…' : 'Démarrer la discussion'),
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

          ],
        ),
      ),
    );
  }
}
