import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/firebase_auth_service.dart';

class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({super.key});

  String get _platform {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      default:
        return defaultTargetPlatform.name;
    }
  }

  String get _url => kIsWeb ? Uri.base.toString() : 'Application native';

  String get _details {
    final auth = FirebaseAuthService.instance;
    final user = auth.currentUser;
    return [
      'Plateforme: $_platform',
      'URL: $_url',
      'Firebase initialisé: ${auth.isConfigured ? 'oui' : 'non'}',
      'Projet Firebase: upchat-android',
      'Utilisateur connecté: ${user?.email ?? user?.phoneNumber ?? 'non'}',
      'Dernière erreur technique: ${auth.lastTechnicalError ?? 'aucune'}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuthService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(auth.isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: auth.isConfigured ? AppColors.accent : Colors.amber),
                    const SizedBox(width: 10),
                    Text(auth.isConfigured ? 'Firebase disponible' : 'Firebase indisponible',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 16),
                  SelectableText(_details),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _details));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostic copié.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copier le diagnostic'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Le Web ne dispose pas de Bluetooth dans le navigateur. '
            'Les messages Web utilisent donc internet ou restent en attente.',
          ),
          if (auth.lastTechnicalError != null) ...[
            const SizedBox(height: 16),
            Text('Le détail technique est conservé ici uniquement.',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}
