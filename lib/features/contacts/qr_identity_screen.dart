import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/services/storage_service.dart';

class QrIdentityScreen extends StatefulWidget {
  const QrIdentityScreen({super.key});

  @override
  State<QrIdentityScreen> createState() => _QrIdentityScreenState();
}

class _QrIdentityScreenState extends State<QrIdentityScreen> {
  bool _scannerOpen = false;
  bool _handled = false;

  String get _payload => jsonEncode({
        'protocol': 'upchat.identity.v1',
        'userId': StorageService.userId,
        'name': StorageService.userName,
      });

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw);
        if (data is Map && data['protocol'] == 'upchat.identity.v1' &&
            data['userId'] is String && (data['userId'] as String).isNotEmpty) {
          _handled = true;
          Navigator.pop(context, Map<String, dynamic>.from(data));
          return;
        }
      } catch (_) {
        // Le scan reste silencieux tant que le QR n'est pas un QR UpChat.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identité locale')), 
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Montre ce code à un contact pour te retrouver sans numéro de téléphone.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: _payload,
                  size: 240,
                  semanticsLabel: 'Identité locale UpChat',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Identifiant : ${StorageService.userId}', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(() => _scannerOpen = !_scannerOpen),
            icon: Icon(_scannerOpen ? Icons.close : Icons.qr_code_scanner),
            label: Text(_scannerOpen ? 'Fermer le scanner' : 'Scanner un contact'),
          ),
          if (_scannerOpen) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(onDetect: _handleCapture),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le QR identifie le contact ; vérifie ensuite l’empreinte de sécurité avant de lui envoyer des messages sensibles.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
