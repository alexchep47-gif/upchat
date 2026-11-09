import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/firebase_auth_service.dart';
import '../../data/services/internet_service.dart';
import '../../providers/profile_provider.dart';
import '../../core/theme/app_colors.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  late final TextEditingController _phone;
  final _code = TextEditingController();
  String? _verificationId;
  ConfirmationResult? _webConfirmation;
  String? _message;
  bool _sending = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+') || phone.length < 10) {
      setState(() => _message = 'Utilise le format international, par exemple +237677152300.');
      return;
    }
    setState(() { _sending = true; _message = null; });
    try {
      final auth = FirebaseAuthService.instance;
      if (kIsWeb) {
        _webConfirmation = await auth.signInWithPhoneNumber(phone);
        _message = 'Valide le contrôle reCAPTCHA puis saisis le code reçu par SMS.';
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phone,
          codeSent: (id) => setState(() {
            _verificationId = id;
            _message = 'Code envoyé. Saisis les 6 chiffres reçus par SMS.';
          }),
          verificationCompleted: (credential) => _link(credential),
          verificationFailed: (error) => setState(() => _message = _friendly(error)),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkCode() async {
    final smsCode = _code.text.trim();
    if (smsCode.length != 6) {
      setState(() => _message = 'Le code doit contenir 6 chiffres.');
      return;
    }
    try {
      final auth = FirebaseAuthService.instance;
      final credential = auth.credential(
        verificationId: kIsWeb ? _webConfirmation!.verificationId : _verificationId!,
        smsCode: smsCode,
      );
      await _link(credential);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    }
  }

  Future<void> _link(PhoneAuthCredential credential) async {
    if (_checking) return;
    setState(() { _checking = true; _message = null; });
    try {
      final result = await FirebaseAuthService.instance.linkWithCredential(credential);
      final phone = result.user?.phoneNumber ?? _phone.text.trim();
      await context.read<ProfileProvider>().updatePhone(phone);
      await result.user?.getIdToken(true);
      await InternetService().reregister(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro vérifié et associé à ton compte.')),
      );
      Navigator.pop(context, phone);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _friendly(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'credential-already-in-use':
        case 'account-exists-with-different-credential':
          return 'Ce numéro est déjà associé à un autre compte.';
        case 'invalid-verification-code':
          return 'Code incorrect. Vérifie le SMS reçu.';
        case 'too-many-requests':
          return 'Trop de tentatives. Attends quelques minutes puis réessaie.';
      }
      return error.message ?? 'La vérification du numéro a échoué.';
    }
    if (error is StateError || error is UnsupportedError) {
      return 'La vérification par SMS n’est pas disponible pour l’instant. '
          'Tu peux utiliser UpChat sans numéro, ou ajouter un contact avec son code QR.';
    }
    return 'La vérification par SMS a échoué. Réessaie plus tard ou continue sans numéro.';
  }

  @override
  Widget build(BuildContext context) {
    final hasCodeRequest = _verificationId != null || _webConfirmation != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier mon numéro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.verified_user_outlined, size: 54, color: AppColors.accent),
          const SizedBox(height: 16),
          const Text('Ton numéro sera vérifié par SMS avant d’être publié dans l’annuaire.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Numéro international', hintText: '+237 677 15 23 00'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _sendCode,
            icon: const Icon(Icons.sms_outlined),
            label: Text(_sending ? 'Envoi…' : 'Envoyer le code SMS'),
          ),
          if (hasCodeRequest) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Code reçu par SMS'),
            ),
            FilledButton.icon(
              onPressed: _checking ? null : _checkCode,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_checking ? 'Vérification…' : 'Vérifier et associer'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }
}
