import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/services/storage_service.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/glass_container.dart';

/// Parcours premier lancement — page d’accueil inspirée Adalo (dark + CTA dégradé),
/// puis permissions et profil (logique Flutter UpChat inchangée).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  int _currentPage = 0;
  bool _requestingPermissions = false;
  String? _permissionMessage;
  PermissionSnapshot _permissions = const PermissionSnapshot(
    bluetoothPermission: false,
    locationPermission: false,
    nearbyWifiPermission: false,
    bluetoothState: BluetoothAdapterState.unknown,
    permanentlyDenied: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (StorageService.isOnboardingDone) {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      } else {
        _refreshPermissions();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final status = await PermissionHelper.readStatus();
    if (mounted) setState(() => _permissions = status);
  }

  Future<void> _requestPermissionsAndContinue() async {
    if (_requestingPermissions) return;
    setState(() {
      _requestingPermissions = true;
      _permissionMessage = null;
    });

    final status = await PermissionHelper.requestAllAndRead();
    if (!mounted) return;
    setState(() {
      _requestingPermissions = false;
      _permissions = status;
    });

    if (status.nearbyReady) {
      _nextPage();
    } else if (status.bluetoothPermission &&
        status.locationPermission &&
        status.bluetoothState == BluetoothAdapterState.disabled) {
      setState(() => _permissionMessage =
          'Les permissions sont accordées, mais le Bluetooth est désactivé sur le téléphone.');
    } else {
      setState(() => _permissionMessage =
          'Certaines autorisations manquent encore. Tu peux les accorder maintenant ou continuer sans la proximité.');
    }
  }

  Future<void> _enableBluetooth() async {
    await PermissionHelper.requestEnableBluetooth();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshPermissions();
  }

  Future<void> _openSettings() async {
    await PermissionHelper.openSettings();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final profile = context.read<ProfileProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isNotEmpty) await profile.updateName(name);
    if (phone.isNotEmpty) await profile.updatePhone(phone);
    await StorageService.setOnboardingDone();
    if (mounted) Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    final isWelcome = _currentPage == 0;
    return Scaffold(
      backgroundColor:
          isWelcome ? const Color(0xFF0B1220) : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (!isWelcome) _OnboardingHeader(page: _currentPage),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  if (page == 1) _refreshPermissions();
                },
                children: [
                  _welcomeAdaloPage(),
                  _pageShell(_permissionsPage()),
                  _pageShell(_profilePage()),
                ],
              ),
            ),
            if (!isWelcome) _PageIndicator(currentPage: _currentPage),
          ],
        ),
      ),
    );
  }

  Widget _pageShell(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: child,
        ),
      ),
    );
  }

  /// Écran d’accueil type Adalo : badge live, pastilles features, CTA dégradé.
  Widget _welcomeAdaloPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Bulles dégradées
              SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 48,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF5B8CFF), Color(0xFFB06BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.more_horiz,
                            color: Colors.white, size: 36),
                      ),
                    ),
                    Positioned(
                      right: 52,
                      top: 8,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B5CFF), Color(0xFF2AABEE)],
                          ),
                          border: Border.all(
                              color: const Color(0xFF0B1220), width: 4),
                        ),
                        child: const Icon(Icons.chat_bubble_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2438),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A3A55)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
                    SizedBox(width: 8),
                    Text(
                      'MESSAGERIE LIVE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'UpChat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Envoie un message, vois les points de présence.\n'
                'En tête-à-tête ou en groupe — photos, proximité\n'
                'et non-lus qui comptent vraiment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9AA8C0),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              _FeatureChip(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xFF5B8CFF),
                label: 'Discussions qui te suivent',
              ),
              const SizedBox(height: 10),
              _FeatureChip(
                icon: Icons.groups_rounded,
                color: const Color(0xFFB06BFF),
                label: 'Fils de groupe pour tes proches',
              ),
              const SizedBox(height: 10),
              _FeatureChip(
                icon: Icons.wifi_tethering_rounded,
                color: const Color(0xFF2AABEE),
                label: 'Voir qui est autour, maintenant',
              ),
              const SizedBox(height: 32),
              // CTA dégradé style Adalo
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _nextPage,
                      child: const Center(
                        child: Text(
                          'Commencer à discuter  →',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRouter.login),
                child: const Text.rich(
                  TextSpan(
                    text: 'Déjà un compte ? ',
                    style: TextStyle(color: Color(0xFF9AA8C0)),
                    children: [
                      TextSpan(
                        text: 'Se connecter',
                        style: TextStyle(
                          color: Color(0xFF7BB8FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionsPage() {
    final canEnableBluetooth = _permissions.bluetoothPermission &&
        _permissions.locationPermission &&
        _permissions.bluetoothState == BluetoothAdapterState.disabled;
    return _ContentCard(
      icon: Icons.bluetooth_searching_rounded,
      title: 'Autoriser la proximité',
      subtitle:
          'UpChat demande les autorisations pour découvrir les appareils proches. L’état ci-dessous vient du téléphone.',
      child: Column(
        children: [
          _PermissionTile(
            icon: Icons.bluetooth_rounded,
            title: 'Bluetooth',
            value: _permissions.isWeb
                ? 'Non requis sur le Web'
                : _permissions.bluetoothLabel,
            ok: _permissions.isWeb ||
                (_permissions.bluetoothPermission &&
                    _permissions.bluetoothState ==
                        BluetoothAdapterState.enabled),
          ),
          const SizedBox(height: 10),
          _PermissionTile(
            icon: Icons.location_on_rounded,
            title: 'Localisation',
            value: _permissions.isWeb
                ? 'Non requise sur le Web'
                : _permissions.locationPermission
                    ? 'Autorisation accordée'
                    : 'Autorisation manquante',
            ok: _permissions.isWeb || _permissions.locationPermission,
          ),
          if (_permissionMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _permissionMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orangeAccent, height: 1.35),
            ),
          ],
          const SizedBox(height: 22),
          _PrimaryButton(
            label: _requestingPermissions
                ? 'Demande en cours…'
                : canEnableBluetooth
                    ? 'Activer le Bluetooth'
                    : 'Autoriser les accès',
            icon: canEnableBluetooth
                ? Icons.bluetooth_rounded
                : Icons.lock_open_rounded,
            loading: _requestingPermissions,
            onPressed: _requestingPermissions
                ? null
                : canEnableBluetooth
                    ? _enableBluetooth
                    : _requestPermissionsAndContinue,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _refreshPermissions,
            child: const Text('Actualiser l’état'),
          ),
          if (_permissions.permanentlyDenied)
            TextButton(
              onPressed: _openSettings,
              child: const Text('Ouvrir les réglages du téléphone'),
            ),
          TextButton(
            onPressed: _nextPage,
            child: const Text('Continuer sans proximité'),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    return _ContentCard(
      icon: Icons.person_rounded,
      title: 'Créer ton profil',
      subtitle:
          'Le nom est visible par tes contacts. Le numéro est facultatif et sert à être trouvé en mode internet.',
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Prénom ou pseudo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone (optionnel)',
              hintText: '+237 6XX XXX XXX',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onSubmitted: (_) => _finish(),
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Commencer',
            icon: Icons.arrow_forward_rounded,
            onPressed: _finish,
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243049)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int page;
  const _OnboardingHeader({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'UpChat',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${page + 1}/3',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _ContentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 24,
      opacity: Theme.of(context).brightness == Brightness.dark ? .74 : .84,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 44),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool ok;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? AppColors.primary : Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? AppColors.online : Colors.orangeAccent,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int currentPage;
  const _PageIndicator({required this.currentPage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: currentPage == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: currentPage == index
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
