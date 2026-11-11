import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/biometric_lock_provider.dart';

/// Masque l’interface au démarrage et après un retour au premier plan lorsque
/// le verrou biométrique est activé dans les réglages.
class AppLockGate extends StatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlockIfNeeded());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<BiometricLockProvider>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        lock.lock();
        break;
      case AppLifecycleState.resumed:
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlockIfNeeded());
        break;
      case AppLifecycleState.inactive:
        // Ne pas verrouiller ici : local_auth passe lui-même par inactive sur
        // Android/iOS et cela créait une boucle de demande biométrique.
        break;
    }
  }

  Future<void> _unlockIfNeeded() async {
    if (!mounted) return;
    final lock = context.read<BiometricLockProvider>();
    if (!lock.isLocked || lock.isAuthenticating) return;
    await lock.unlock();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<BiometricLockProvider>();
    final result = lock.lastResult;
    final message =
        result?.message ??
        'Utilise la biométrie enregistrée sur ce téléphone pour continuer.';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Offstage garde le navigateur vivant sans laisser apparaître les
        // conversations derrière l’écran de verrouillage.
        Offstage(offstage: lock.isLocked, child: widget.child),
        if (lock.isLocked)
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: .14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.primary,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'UpChat est verrouillé',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: lock.isAuthenticating
                                ? null
                                : _unlockIfNeeded,
                            icon: lock.isAuthenticating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              lock.isAuthenticating
                                  ? 'Vérification…'
                                  : 'Déverrouiller',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: lock.isAuthenticating ? null : _unlockIfNeeded,
                          icon: const Icon(Icons.password_rounded),
                          label: const Text('Utiliser le code du téléphone'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tes données restent sur ce téléphone. UpChat ne stocke jamais ta biométrie.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
