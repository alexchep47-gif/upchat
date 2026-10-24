import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../providers/profile_provider.dart';
import '../../core/utils/permission_helper.dart';

/// Écran de premier lancement : explication P2P + permissions + nom + téléphone
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  int _currentPage = 0;
  bool _requestingPermissions = false;

  @override
  void initState() {
    super.initState();
    if (StorageService.isOnboardingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndContinue() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);

    try {
      await PermissionHelper.requestAll();
    } catch (_) {}

    if (mounted) {
      setState(() => _requestingPermissions = false);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final profile = context.read<ProfileProvider>();

    if (name.isNotEmpty) {
      await profile.updateName(name);
    }
    if (phone.isNotEmpty) {
      await profile.updatePhone(phone);
    }
    await StorageService.setOnboardingDone();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 1 — Bienvenue
                  _buildPage(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Bienvenue sur UpChat',
                    subtitle:
                        'La messagerie qui fonctionne sans internet.\nBluetooth + WiFi Direct = discussion même hors réseau.\n\nLe mode internet optionnel permet d\'ajouter des contacts par numéro de téléphone.',
                    buttonLabel: 'Continuer',
                    onPressed: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                  ),
                  // Page 2 — Permissions
                  _buildPage(
                    icon: Icons.bluetooth_searching_rounded,
                    title: 'Permissions nécessaires',
                    subtitle:
                        'UpChat a besoin de Bluetooth, Localisation et Caméra pour découvrir les appareils proches et envoyer des médias.\n\nTu pourras les accorder plus tard dans les réglages du téléphone.',
                    buttonLabel:
                        _requestingPermissions ? 'Patiente…' : 'Autoriser',
                    onPressed: _requestingPermissions
                        ? null
                        : _requestPermissionsAndContinue,
                    secondaryButtonLabel: 'Passer cette étape',
                    onSecondaryPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  // Page 3 — Nom + téléphone
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 80, color: AppColors.primary),
                        const SizedBox(height: 24),
                        const Text(
                          'Ton profil',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Le nom est visible en local. Le numéro sert uniquement au mode internet pour te trouver à distance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Prénom ou pseudo',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            hintText: '+237 6XX XXX XXX (optionnel)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            helperText:
                                'Recommandé pour le mode internet / longue distance',
                          ),
                          onSubmitted: (_) => _finish(),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: const Text('Commencer',
                                style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback? onPressed,
    String? secondaryButtonLabel,
    VoidCallback? onSecondaryPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: AppColors.primary),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 16)),
            ),
          ),
          if (secondaryButtonLabel != null && onSecondaryPressed != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSecondaryPressed,
              child: Text(
                secondaryButtonLabel,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
