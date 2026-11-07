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

class AddContactByPhoneScreen extends StatefulWidget {
  const AddContactByPhoneScreen({super.key});

  @override
  State<AddContactByPhoneScreen> createState() => _AddContactByPhoneScreenState();
}

class _AddContactByPhoneScreenState extends State<AddContactByPhoneScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _internet = InternetService();
  final _directory = PhoneDirectoryService();
  bool _loading = false;
  String? _message;
  String? _technicalState;
  UserModel? _foundUser;

  String get _normalized => StorageService.normalizePhone(_phoneController.text);
  bool get _validPhone => _normalized.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connectivity = context.read<ConnectivityProvider>();
      if (!connectivity.internetModeEnabled) {
        await connectivity.setInternetMode(true);
        if (mounted) setState(() {});
      }
    });
  }

  void _onPhoneChanged() {
    if (!mounted) return;
    setState(() {
      _message = null;
      _technicalState = null;
      _foundUser = null;
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    final normalized = _normalized;
    if (!_validPhone) {
      setState(() => _message = 'Ce numéro n’est pas valide. Exemple : +237 6 77 15 23 00');
      return;
    }
    final myPhone = StorageService.userPhone;
    if (myPhone != null && StorageService.normalizePhone(myPhone) == normalized) {
      setState(() => _message = 'C’est ton propre numéro.');
      return;
    }
    final profile = context.read<ProfileProvider>();
    if (profile.phoneNumber == null || profile.phoneNumber!.isEmpty) {
      setState(() => _message = 'Vérifie ton numéro pour que tes contacts te trouvent.');
      return;
    }

    setState(() {
      _loading = true;
      _message = 'Recherche du contact…';
      _technicalState = 'lookup_started';
      _foundUser = null;
    });

    try {
      final user = await _internet.lookupByPhone(normalized, requireRegisteredAccount: true);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _loading = false;
          _message = 'Ce numéro n’utilise pas encore UpChat.';
          _technicalState = 'not_found';
        });
        return;
      }
      _foundUser = user;
      setState(() {
        _loading = false;
        _message = 'Contact trouvé';
        _technicalState = 'found';
      });
    } on InternetLookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = error.message;
        _technicalState = 'http_${error.statusCode ?? 'network'}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Pas de connexion internet.';
        _technicalState = 'network';
      });
    }
  }

  Future<void> _openChat(UserModel user) async {
    final name = _nameController.text.trim();
    final resolved = name.isEmpty ? user : user.copyWith(name: name);
    await _directory.upsert(resolved);
    if (!mounted) return;
    final conv = context.read<ChatProvider>().getOrCreateConversation(
      peerId: resolved.id,
      peerName: resolved.name,
    );
    Navigator.pushReplacementNamed(context, AppRouter.chat, arguments: {
      'conversationId': conv.id,
      'peerName': resolved.name,
      'peerId': resolved.id,
    });
  }

  Future<void> _continueOffline() async {
    if (!_validPhone) return;
    final name = _nameController.text.trim().isEmpty
        ? _normalized
        : _nameController.text.trim();
    final pending = UserModel(
      id: 'pending_${_normalized.replaceAll('+', '')}',
      name: name,
      phoneNumber: _normalized,
    );
    await _directory.upsert(pending);
    if (!mounted) return;
    final conv = context.read<ChatProvider>().getOrCreateConversation(
      peerId: pending.id,
      peerName: pending.name,
    );
    Navigator.pushReplacementNamed(context, AppRouter.chat, arguments: {
      'conversationId': conv.id,
      'peerName': pending.name,
      'peerId': pending.id,
      'pendingVerification': true,
    });
  }

  String _displayPhone(String phone) {
    if (!phone.startsWith('+237') || phone.length != 13) return phone;
    final d = phone.substring(4);
    return '+237 ${d[0]} ${d.substring(1, 3)} ${d.substring(3, 5)} ${d.substring(5, 7)} ${d.substring(7)}';
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final hasMyPhone = profile.phoneNumber?.isNotEmpty == true;
    final isNotFound = _technicalState == 'not_found';
    final canRetry = _technicalState == 'network' ||
        (_technicalState?.startsWith('http_5') ?? false);
    final canContinue = canRetry;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle discussion')),
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
              child: Row(children: [
                const CircleAvatar(
                  backgroundColor: AppColors.accent,
                  child: Icon(Icons.person_add_alt_1, color: Colors.white),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Par numéro de téléphone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Retrouve un contact à distance par son numéro (mode internet).', style: TextStyle(fontSize: 13)),
                  ],
                )),
              ]),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              const Text('La proximité demande un téléphone Android. Sur iPhone et sur le web, utilise le mode internet.', style: TextStyle(color: Colors.blue)),
            ],
            const SizedBox(height: 14),
            if (!hasMyPhone)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                title: const Text('Ton numéro n’est pas vérifié'),
                subtitle: const Text('Vérifie ton numéro dans Profil pour être trouvé.'),
                trailing: TextButton(onPressed: () => Navigator.pushNamed(context, AppRouter.profile), child: const Text('Profil')),
              )
            else
              Text('Connecté en tant que ${_displayPhone(profile.phoneNumber!)}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            _label('Numéro de téléphone'),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              enabled: !_loading,
              decoration: const InputDecoration(hintText: '+237 6 77 15 23 00', prefixIcon: Icon(Icons.phone)),
              onSubmitted: (_) => _startChat(),
            ),
            if (_validPhone) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Format utilisé : ${_displayPhone(_normalized)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            _label('Nom du contact (optionnel)'),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              enabled: !_loading,
              decoration: const InputDecoration(hintText: 'Comme dans ton carnet', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_loading) const Padding(padding: EdgeInsets.only(right: 8, top: 2), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                Expanded(child: Text(_message!, style: TextStyle(color: _technicalState == 'found' ? AppColors.accent : Colors.redAccent, height: 1.3))),
              ]),
            ],
            if (_foundUser != null) ...[
              const SizedBox(height: 12),
              Card(child: ListTile(leading: CircleAvatar(child: Text(_foundUser!.name.isEmpty ? '?' : _foundUser!.name.substring(0, 1).toUpperCase())), title: Text(_foundUser!.name), subtitle: const Text('Sur UpChat'), trailing: TextButton(onPressed: () => _openChat(_foundUser!), child: const Text('Écrire')))),
            ],
            if (isNotFound) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _startChat, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
              const Text('Tu peux partager ton numéro par un autre moyen pour inviter ce contact.', style: TextStyle(color: Colors.grey)),
            ],
            if (canRetry) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _startChat, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
              OutlinedButton.icon(onPressed: _continueOffline, icon: const Icon(Icons.offline_bolt), label: const Text('Continuer quand même')),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (!_validPhone || _loading || _foundUser != null || !hasMyPhone) ? null : _startChat,
                icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                label: Text(_loading ? 'Recherche…' : 'Rechercher le contact'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
              ),
            ),
            if (canContinue) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Le contact sera marqué « À vérifier » jusqu’au retour du service.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
