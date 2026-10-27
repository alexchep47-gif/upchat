import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/internet_service.dart';
import '../../data/services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _expanded = false;
  bool _creatingAccount = false;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    // Prefer pop; if opened as root, replace with home.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.home,
        (route) => false,
      );
    }
  }

  Future<void> _onAuthSuccess(UserCredential? cred) async {
    if (cred?.user == null) {
      if (mounted) {
        setState(() => _message = FirebaseAuthService.instance.lastError ??
            'Connexion annulée ou impossible.');
      }
      return;
    }
    final user = cred!.user!;
    // Aligne l’ID local avec Firebase pour que le serveur de signalisation
    // retrouve le même utilisateur sur les deux téléphones.
    await StorageService.setUserId(user.uid);
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      await StorageService.setUserName(user.displayName!.trim());
    }
    // Active le mode internet et ré-enregistre le device.
    await InternetService().setEnabled(true);
    await InternetService().reregister();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecté : ${user.email ?? user.uid}')),
    );
    await _goHome();
  }

  Future<void> _run(Future<UserCredential?> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final ok = await FirebaseAuthService.instance.initialize();
      if (!ok) {
        if (mounted) {
          setState(() => _message =
              FirebaseAuthService.instance.lastError ??
                  'Firebase non configuré sur cet appareil. Vérifie google-services.json / secrets CI.');
        }
        return;
      }
      final result = await action();
      await _onAuthSuccess(result);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _message = _mapFirebaseError(error));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message =
            'Erreur : $error\nVérifie SHA-1 dans Firebase Console et le client OAuth Web.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Pas de réseau. Réessaie avec une connexion internet.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cet e-mail est déjà utilisé. Connecte-toi plutôt.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec une autre méthode.';
      default:
        return error.message ?? 'Connexion impossible (${error.code}).';
    }
  }

  Future<void> _emailLogin() async {
    await _run(() => FirebaseAuthService.instance.signInWithEmail(
          _email.text,
          _password.text,
        ));
  }

  Future<void> _googleLogin() async {
    await _run(() => FirebaseAuthService.instance.signInWithGoogle());
  }

  Future<void> _createAccount() async {
    await _run(() async {
      if (_email.text.trim().isEmpty || _password.text.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message:
              'Utilise une adresse e-mail et un mot de passe d’au moins 6 caractères.',
        );
      }
      return FirebaseAuthService.instance
          .createAccount(_email.text, _password.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF111827);
    final muted = dark ? Colors.white70 : const Color(0xFF6B7280);
    return Scaffold(
      backgroundColor: dark ? AppColors.backgroundDark : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset('assets/upchat_u_icon.png',
                              width: 104, height: 104),
                        ),
                        const SizedBox(height: 14),
                        // Bouton réellement cliquable (avant : simple Text)
                        TextButton.icon(
                          onPressed: _loading ? null : _goHome,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text(
                            'RETOUR À L’ACCUEIL',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text('Connexion',
                      style: TextStyle(
                          color: text,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Le même compte sur tous tes appareils.',
                      style: TextStyle(color: muted, fontSize: 16)),
                  const SizedBox(height: 28),
                  _AuthButton(
                    icon: const Text('G',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4285F4))),
                    label: 'Continuer avec Google',
                    onPressed: _loading ? null : _googleLogin,
                  ),
                  const SizedBox(height: 20),
                  Divider(color: muted.withOpacity(.25)),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Se connecter avec une adresse e-mail',
                              style: TextStyle(
                                  color: text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: muted),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded) ...[
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading
                            ? null
                            : (_creatingAccount ? _createAccount : _emailLogin),
                        child: Text(_loading
                            ? 'Patiente…'
                            : (_creatingAccount
                                ? 'Créer mon compte'
                                : 'Se connecter')),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: TextStyle(
                          color:
                              dark ? Colors.orangeAccent : Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _expanded = true;
                                _creatingAccount = !_creatingAccount;
                                _message = null;
                              }),
                      child: Text(
                        _creatingAccount
                            ? 'J’ai déjà un compte'
                            : 'Créer mon compte',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;
  const _AuthButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.center,
            side: BorderSide(color: Theme.of(context).dividerColor),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}
