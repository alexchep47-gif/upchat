import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/cleanup_service.dart';
import '../../providers/theme_provider.dart';

/// Écran des réglages
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cleaning = false;

  Future<void> _runCleanup() async {
    setState(() => _cleaning = true);
    final report = await CleanupService().run();
    setState(() => _cleaning = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            report.total == 0
                ? 'Rien à nettoyer'
                : 'Nettoyé : ${report.storiesDeleted} stories, ${report.mediaDeleted} médias',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Apparence', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Clair'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            activeColor: AppColors.accent,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Sombre (OLED)'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            activeColor: AppColors.accent,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Système'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            activeColor: AppColors.accent,
            onChanged: (v) => themeProvider.setThemeMode(v!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Nettoyer le stockage'),
            subtitle: const Text('Stories expirées + médias > 7 jours'),
            trailing: _cleaning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _cleaning ? null : _runCleanup,
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: const Text('Effacer toutes les discussions'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmer'),
                  content: const Text(
                    'Tous les messages et conversations seront supprimés de cet appareil.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Effacer', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await StorageService.clearChats();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discussions effacées')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            subtitle: Text('${AppConstants.appName} v${AppConstants.appVersion}'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationLegalese:
                    'Messagerie P2P 100 % offline\nBluetooth + WiFi Direct + Mesh',
              );
            },
          ),
        ],
      ),
    );
  }
}
