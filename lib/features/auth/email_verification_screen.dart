import 'package:flutter/material.dart';

import '../../data/services/firebase_auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _loading = false;
  String? _message;

  Future<void> _sendAgain() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await FirebaseAuthService.instance.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Un nouveau lien de vérification vient d’être envoyé.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Impossible d’envoyer l’e-mail pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final verified = await FirebaseAuthService.instance.refreshEmailVerification();
      if (!mounted) return;
      if (verified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _message = 'Le lien n’est pas encore validé. Ouvre-le puis réessaie.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Vérification impossible pour le moment.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuthService.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier ton e-mail')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 72),
                  const SizedBox(height: 20),
                  const Text(
                    'Confirme que cette adresse t’appartient',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Un lien de vérification a été envoyé à $email. Après validation, UpChat ouvrira directement ton compte et conservera son état local.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _check,
                      icon: const Icon(Icons.verified_outlined),
                      label: Text(_loading ? 'Vérification…' : 'J’ai vérifié mon e-mail'),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _sendAgain,
                    child: const Text('Renvoyer l’e-mail'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
