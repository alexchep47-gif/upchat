import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/cleanup_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/connectivity_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cleaning = false;
  late bool _autoCleanup;
  late bool _autoPlayStories;
  late int _storyDuration;

  @override
  void initState() {
    super.initState();
    _autoCleanup = StorageService.autoCleanup;
    _autoPlayStories = StorageService.autoPlayStories;
    _storyDuration = StorageService.storyViewDuration;
  }

  Future<void> _runCleanup() async {
    setState(() => _cleaning = true);
    final report = await CleanupService().run();
    if (mounted) setState(() => _cleaning = false);

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

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppConstants.appName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${AppConstants.appVersion}'),
            const SizedBox(height: 12),
            const Text(
              'Messagerie P2P 100 % offline\nBluetooth + WiFi Direct + Mesh\nMode internet optionnel (hybride)',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              AppConstants.authorCredit,
              style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Offline : portée locale (dizaines de mètres).\n'
              'Mode internet : Android ↔ iPhone, longue distance\n'
              '(nécessite un réseau et un serveur de signalisation).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final connectivity = context.watch<ConnectivityProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          // Mode internet
          const ListTile(
            title: Text('Connexion', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Mode internet (optionnel)'),
            subtitle: Text(
              connectivity.internetModeEnabled
                  ? (connectivity.isOnline
                      ? 'Actif — hybride (local + internet)'
                      : 'Activé — en attente de réseau')
                  : 'Désactivé — 100 % offline local',
            ),
            value: connectivity.internetModeEnabled,
            activeColor: AppColors.accent,
            onChanged: (v) async {
              await connectivity.setInternetMode(v);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v
                          ? 'Mode internet activé. Android ↔ iPhone et longue distance seront possibles avec un serveur de signalisation.'
                          : 'Retour au mode 100 % offline local.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          if (connectivity.internetModeEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Le mode internet permet la communication entre Android et iPhone, '
                'ainsi que les messages / appels à longue distance. '
                'Un petit serveur de signalisation sera nécessaire pour la mise en production.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
              ),
            ),

          const Divider(),

          // Apparence
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

          const ListTile(
            title: Text('Stories', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.play_circle_outline_rounded),
            title: const Text('Lecture automatique'),
            subtitle: Text(
              _autoPlayStories
                  ? 'Les stories avancent automatiquement'
                  : 'Passe à la story suivante manuellement',
            ),
            value: _autoPlayStories,
            activeColor: AppColors.accent,
            onChanged: (value) async {
              await StorageService.setAutoPlayStories(value);
              if (mounted) setState(() => _autoPlayStories = value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Durée par story'),
            subtitle: const Text('Temps d’affichage avant le passage suivant'),
            trailing: DropdownButton<int>(
              value: _storyDuration,
              items: const [3, 5, 8, 10, 15]
                  .map(
                    (seconds) => DropdownMenuItem<int>(
                      value: seconds,
                      child: Text('${seconds}s'),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                await StorageService.setStoryViewDuration(value);
                if (mounted) setState(() => _storyDuration = value);
              },
            ),
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
          SwitchListTile(
            secondary: const Icon(Icons.auto_delete_outlined),
            title: const Text('Nettoyage automatique'),
            subtitle: const Text('Nettoyer les stories expirées au démarrage'),
            value: _autoCleanup,
            activeColor: AppColors.accent,
            onChanged: (value) async {
              await StorageService.setAutoCleanup(value);
              if (mounted) setState(() => _autoCleanup = value);
            },
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
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Mon profil'),
            subtitle: const Text('Nom, photo et numéro de téléphone'),
            onTap: () => Navigator.pushNamed(context, AppRouter.profile),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos'),
            subtitle: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}\n'
              '${AppConstants.authorName}',
            ),
            isThreeLine: true,
            onTap: _showAbout,
          ),
        ],
      ),
    );
  }
}
