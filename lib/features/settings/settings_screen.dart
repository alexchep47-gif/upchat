import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/cleanup_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/responsive_content.dart';

/// Centre de préférences unique : les valeurs sont partagées et persistées
/// pour que les écrans de chat, profil, notifications et stockage restent alignés.
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
    if (!mounted) return;
    setState(() => _cleaning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(report.total == 0
            ? 'Rien à nettoyer'
            : 'Nettoyé : ${report.storiesDeleted} stories, ${report.mediaDeleted} médias'),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 9),
              Text(title.toUpperCase(), style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8)),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _toggle({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile.adaptive(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeColor: AppColors.accent,
      onChanged: onChanged,
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(.14),
              child: const Icon(Icons.chat_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Text(AppConstants.appName),
          ],
        ),
        content: Text(
          'Version ${AppConstants.appVersion}\n\n'
          'Messagerie privée hybride : proximité, Wi‑Fi Direct, réseau maillé et relais internet optionnel.\n\n'
          '${AppConstants.authorCredit}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final connectivity = context.watch<ConnectivityProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Réglages'),
        actions: [
          IconButton(
            tooltip: 'Rechercher dans les réglages',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => showSearch(context: context, delegate: _SettingsSearchDelegate()),
          ),
        ],
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.only(top: kToolbarHeight + 12, bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRouter.profile),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary.withOpacity(.14),
                          child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(StorageService.userName.isEmpty ? 'Mon profil' : StorageService.userName, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 3),
                              Text(StorageService.userPhone ?? 'Ajouter un numéro de téléphone', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _section('Compte', Icons.person_outline_rounded, [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Mon profil'),
                subtitle: const Text('Nom, photo, bio et numéro de téléphone'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, AppRouter.profile),
              ),
              ListTile(
                leading: const Icon(Icons.devices_other_rounded),
                title: const Text('Appareils connectés'),
                subtitle: const Text('Gérer les sessions et les appareils autorisés'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(context, AppRouter.connectedDevices),
              ),
            ]),
            _section('Confidentialité', Icons.lock_outline_rounded, [
              _toggle(icon: Icons.done_all_rounded, title: 'Confirmations de lecture', subtitle: 'Afficher et recevoir les coches bleues', value: settings.readReceipts, onChanged: settings.setReadReceipts),
              _toggle(icon: Icons.circle, title: 'Présence en ligne', subtitle: 'Partager mon statut en ligne avec mes contacts', value: settings.onlineStatus, onChanged: settings.setOnlineStatus),
              _toggle(icon: Icons.keyboard_alt_outlined, title: 'Indicateur de saisie', subtitle: 'Afficher quand un contact écrit', value: settings.typingIndicators, onChanged: settings.setTypingIndicators),
            ]),
            _section('Notifications', Icons.notifications_none_rounded, [
              _toggle(icon: Icons.volume_up_outlined, title: 'Sons', subtitle: 'Sons des messages et des appels', value: settings.notificationSounds, onChanged: settings.setNotificationSounds),
              _toggle(icon: Icons.vibration_rounded, title: 'Vibration', subtitle: 'Vibrer pour les nouveaux messages', value: settings.notificationVibration, onChanged: settings.setNotificationVibration),
              _toggle(icon: Icons.visibility_outlined, title: 'Aperçu du message', subtitle: 'Afficher le contenu dans les notifications', value: settings.notificationPreview, onChanged: settings.setNotificationPreview),
            ]),
            _section('Discussions', Icons.chat_bubble_outline_rounded, [
              _toggle(icon: Icons.keyboard_return_rounded, title: 'Entrée pour envoyer', subtitle: 'La touche Entrée envoie le message', value: settings.enterToSend, onChanged: settings.setEnterToSend),
              ListTile(
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Taille du texte'),
                subtitle: Text('${(settings.chatFontScale * 100).round()} % dans les discussions'),
                trailing: DropdownButton<double>(
                  value: settings.chatFontScale,
                  underline: const SizedBox.shrink(),
                  items: const [0.9, 1.0, 1.1, 1.2].map((v) => DropdownMenuItem(value: v, child: Text('${(v * 100).round()} %'))).toList(),
                  onChanged: (v) { if (v != null) settings.setChatFontScale(v); },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.wallpaper_outlined),
                title: const Text('Fond des discussions'),
                subtitle: const Text('Apparence cohérente avec le thème actif'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showInfo('Fond des discussions', 'Le fond suit automatiquement le mode clair ou sombre et reste commun à tous les chats.'),
              ),
            ]),
            _section('Données et stockage', Icons.data_usage_rounded, [
              _toggle(icon: Icons.download_for_offline_outlined, title: 'Téléchargement automatique', subtitle: 'Récupérer les photos et fichiers sur réseau autorisé', value: settings.autoDownloadMedia, onChanged: settings.setAutoDownloadMedia),
              _toggle(icon: Icons.photo_library_outlined, title: 'Enregistrer dans la galerie', subtitle: 'Copier les médias reçus dans la galerie', value: settings.saveToGallery, onChanged: settings.setSaveToGallery),
              _toggle(icon: Icons.data_saver_on_outlined, title: 'Mode économie de données', subtitle: 'Réduire les médias et synchronisations en arrière-plan', value: settings.lowDataMode, onChanged: settings.setLowDataMode),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Nettoyer le stockage'),
                subtitle: const Text('Stories expirées et médias anciens'),
                trailing: _cleaning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                onTap: _cleaning ? null : _runCleanup,
              ),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.auto_delete_outlined),
                title: const Text('Nettoyage automatique'),
                subtitle: const Text('Nettoyer les stories expirées au démarrage'),
                value: _autoCleanup,
                onChanged: (v) async { await StorageService.setAutoCleanup(v); if (mounted) setState(() => _autoCleanup = v); },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Durée des stories'),
                subtitle: Text('$_storyDuration secondes par story'),
                trailing: DropdownButton<int>(
                  value: _storyDuration,
                  underline: const SizedBox.shrink(),
                  items: const [3, 5, 8, 10, 15].map((v) => DropdownMenuItem(value: v, child: Text('${v}s'))).toList(),
                  onChanged: (v) async { if (v == null) return; await StorageService.setStoryViewDuration(v); if (mounted) setState(() => _storyDuration = v); },
                ),
              ),
            ]),
            _section('Connexion', Icons.hub_outlined, [
              SwitchListTile.adaptive(
                secondary: Icon(connectivity.isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                title: const Text('Mode internet hybride'),
                subtitle: Text(connectivity.internetModeEnabled ? (connectivity.isOnline ? 'Actif — local + relais internet' : 'Activé — en attente du réseau') : 'Désactivé — fonctionnement local'),
                value: connectivity.internetModeEnabled,
                onChanged: connectivity.setInternetMode,
              ),
            ]),
            _section('Apparence', Icons.palette_outlined, [
              RadioListTile<ThemeMode>(title: const Text('Clair'), value: ThemeMode.light, groupValue: themeProvider.themeMode, onChanged: (v) => themeProvider.setThemeMode(v!)),
              RadioListTile<ThemeMode>(title: const Text('Sombre OLED'), value: ThemeMode.dark, groupValue: themeProvider.themeMode, onChanged: (v) => themeProvider.setThemeMode(v!)),
              RadioListTile<ThemeMode>(title: const Text('Selon le système'), value: ThemeMode.system, groupValue: themeProvider.themeMode, onChanged: (v) => themeProvider.setThemeMode(v!)),
              _toggle(icon: Icons.blur_on_rounded, title: 'Barre d’outils transparente', subtitle: 'Style translucide adaptatif clair et sombre', value: settings.transparentToolbar, onChanged: settings.setTransparentToolbar),
            ]),
            _section('Stockage local', Icons.security_outlined, [
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
                title: const Text('Effacer toutes les discussions'),
                subtitle: const Text('Supprime les messages de cet appareil'),
                onTap: _confirmClearChats,
              ),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('À propos'), subtitle: Text('${AppConstants.appName} v${AppConstants.appVersion}'), onTap: _showAbout),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearChats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer les discussions ?'),
        content: const Text('Tous les messages et conversations seront supprimés de cet appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Effacer')),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearChats();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discussions effacées')));
    }
  }

  void _showInfo(String title, String message) {
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
  }
}

class _SettingsSearchDelegate extends SearchDelegate<void> {
  final _items = const ['Mon profil', 'Appareils connectés', 'Confidentialité', 'Confirmations de lecture', 'Présence en ligne', 'Notifications', 'Sons', 'Vibration', 'Discussions', 'Entrée pour envoyer', 'Données et stockage', 'Mode économie de données', 'Apparence', 'Barre d’outils transparente'];

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final matches = _items.where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();
    return ListView.builder(itemCount: matches.length, itemBuilder: (_, index) => ListTile(title: Text(matches[index])));
  }
}
