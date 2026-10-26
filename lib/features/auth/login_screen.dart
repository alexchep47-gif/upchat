import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _expanded = false;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _message = error.message ?? 'Connexion impossible.');
    } catch (error) {
      if (mounted) setState(() => _message = 'La connexion est indisponible pour le moment. Tu peux continuer à utiliser UpChat hors ligne.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _emailLogin() async {
    await _run(() async {
      final result = await FirebaseAuthService.instance.signInWithEmail(
        _email.text,
        _password.text,
      );
      if (result == null && mounted) {
        setState(() => _message = FirebaseAuthService.instance.lastError);
      }
    });
  }

  Future<void> _googleLogin() async {
    await _run(() async {
      final result = await FirebaseAuthService.instance.signInWithGoogle();
      if (result == null && mounted) {
        setState(() => _message = FirebaseAuthService.instance.lastError);
      }
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
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 24),
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
                          child: Image.asset('assets/upchat_u_icon.png', width: 104, height: 104),
                        ),
                        const SizedBox(height: 14),
                        Text('RETOUR À L’ACCUEIL', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 62),
                  Text('Connexion', style: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Le même compte sur tous tes appareils.', style: TextStyle(color: muted, fontSize: 18)),
                  const SizedBox(height: 32),
                  _AuthButton(
                    icon: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                    label: 'Continuer avec Google',
                    onPressed: _loading ? null : _googleLogin,
                  ),
                  const SizedBox(height: 14),
                  _AuthButton(
                    icon: Icon(Icons.apple, color: text, size: 25),
                    label: 'Continuer avec Apple',
                    onPressed: null,
                  ),
                  const SizedBox(height: 24),
                  Divider(color: muted.withOpacity(.25)),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        children: [
                          Expanded(child: Text('Se connecter avec une adresse e-mail', style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w600))),
                          Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: muted),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded) ...[
                    TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Adresse e-mail', prefixIcon: Icon(Icons.mail_outline))),
                    const SizedBox(height: 12),
                    TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline))),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: FilledButton(onPressed: _loading ? null : _emailLogin, child: Text(_loading ? 'Connexion…' : 'Se connecter'))),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, style: TextStyle(color: dark ? Colors.orangeAccent : Colors.redAccent)),
                  ],
                  const SizedBox(height: 34),
                  Center(child: Text.rich(TextSpan(text: 'Pas encore de compte ? ', style: TextStyle(color: muted, fontSize: 16), children: [TextSpan(text: 'Créer mon compte', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))]))),
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
  const _AuthButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.center,
            side: BorderSide(color: Theme.of(context).dividerColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}
