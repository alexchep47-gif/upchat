import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/responsive_content.dart';
import '../../data/services/media_service.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/profile_avatar.dart';

/// Écran de profil utilisateur
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _nameController = TextEditingController(text: profile.name);
    _bioController = TextEditingController(text: profile.bio ?? '');
    _phoneController =
        TextEditingController(text: profile.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    if (_pickingPhoto) return;

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (context.read<ProfileProvider>().photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    if (source == 'remove') {
      await context.read<ProfileProvider>().updatePhoto(null);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo supprimée')),
        );
      }
      return;
    }

    setState(() => _pickingPhoto = true);

    try {
      final media = MediaService();
      final path = await media.pickImage(fromCamera: source == 'camera');
      if (path != null && mounted) {
        await context.read<ProfileProvider>().updatePhoto(path);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo de profil mise à jour')),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur photo profil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de changer la photo ($e)')),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton(
            onPressed: () async {
              await profile.updateName(_nameController.text);
              await profile.updateBio(_bioController.text);
              await profile.updatePhone(_phoneController.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Center(
            child: Stack(
              children: [
                ProfileAvatar(
                  name: profile.name,
                  photoPath: profile.photoPath,
                  radius: 56,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickingPhoto ? null : _changePhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _pickingPhoto
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _pickingPhoto ? null : _changePhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_pickingPhoto ? 'Chargement…' : 'Changer la photo'),
            ),
          ),
          if (profile.photoPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                kIsWeb
                    ? 'Aperçu photo limité sur le web'
                    : 'Photo enregistrée',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '+237 6XX XXX XXX',
              prefixIcon: Icon(Icons.phone),
              helperText:
                  'Utilisé uniquement en mode internet pour te retrouver à distance',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              prefixIcon: Icon(Icons.info_outline),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Identifiant local'),
            subtitle:
                Text(profile.userId, style: const TextStyle(fontSize: 12)),
          ),
          ],
        ),
      ),
    );
  }
}
