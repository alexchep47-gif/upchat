import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nearby_connections_plus/flutter_nearby_connections_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/internet_service.dart';

class NearbyDevicesPage extends StatefulWidget {
  const NearbyDevicesPage({super.key});

  @override
  State<NearbyDevicesPage> createState() => _NearbyDevicesPageState();
}

class _NearbyDevicesPageState extends State<NearbyDevicesPage> {
  final NearbyService _nearbyService = NearbyService();
  final InternetService _internetService = InternetService();
  final TextEditingController _webPeerController = TextEditingController();
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _messagesSubscription;
  List<Device> _devices = const [];
  bool _isRunning = false;
  bool _isStarting = false;
  String? _error;
  final TextEditingController _messageController = TextEditingController();
  String? _selectedDeviceId;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _devicesSubscription = _nearbyService.stateChangedSubscription(
      callback: (devices) {
        if (mounted) setState(() => _devices = List<Device>.from(devices));
      },
    );
    _messagesSubscription = _nearbyService.dataReceivedSubscription(
      callback: (payload) {
        if (!mounted) return;
        setState(() => _lastMessage = payload.toString());
      },
    );
    _internetService.onMessageReceived = (message) {
      if (mounted) setState(() => _lastMessage = '${message.senderName} : ${message.content}');
    };
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    if (kIsWeb || _isStarting || _isRunning) return;
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      await _nearbyService.init(
        serviceType: 'cmr-connect',
        strategy: Strategy.P2P_CLUSTER,
        deviceName: 'CmrSchoolAI',
        callback: (running) {
          if (mounted) setState(() => _isRunning = running == true);
        },
      );
      await _nearbyService.startAdvertisingPeer(deviceName: 'CmrSchoolAI');
      await _nearbyService.startBrowsingForPeers();
      if (mounted) setState(() => _isRunning = true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Active le Bluetooth, le Wi‑Fi et les autorisations à proximité.');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _stopDiscovery() async {
    if (kIsWeb) return;
    await _nearbyService.stopBrowsingForPeers();
    await _nearbyService.stopAdvertisingPeer();
    if (mounted) setState(() => _isRunning = false);
  }

  @override
  void dispose() {
    unawaited(_stopDiscovery());
    _devicesSubscription?.cancel();
    _messagesSubscription?.cancel();
    _webPeerController.dispose();
    _messageController.dispose();
    unawaited(_internetService.setEnabled(false));
    super.dispose();
  }

  Future<void> _sendWebMessage() async {
    final target = _webPeerController.text.trim();
    final text = _messageController.text.trim();
    if (target.isEmpty || text.isEmpty) return;
    final sent = await _internetService.sendMessage(targetUserId: target, conversationId: target, text: text);
    if (mounted) setState(() => _lastMessage = sent ? 'Moi : $text' : 'Message mis en attente — reconnexion en cours');
    if (sent) _messageController.clear();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final deviceId = _selectedDeviceId;
    if (message.isEmpty || deviceId == null || kIsWeb) return;
    await _nearbyService.sendMessage(deviceId, message);
    if (mounted) {
      setState(() => _lastMessage = 'Moi : $message');
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    return Scaffold(
      appBar: AppBar(title: const Text('Appareils à proximité')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: AppTheme.navy,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.wifi_tethering, color: AppTheme.orange, size: 34),
                const SizedBox(height: 12),
                Text('Connexion directe', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Détecte les téléphones proches grâce au Wi‑Fi pair-à-pair et au Bluetooth, sans serveur.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: isWeb || _isStarting ? null : (_isRunning ? _stopDiscovery : _startDiscovery),
                  icon: Icon(_isRunning ? Icons.stop_circle_outlined : Icons.radar),
                  label: Text(_isStarting ? 'Activation…' : (_isRunning ? 'Arrêter la détection' : 'Rechercher autour de moi')),
                ),
              ]),
            ),
          ),
          if (isWeb)
            Card(
              margin: const EdgeInsets.only(top: 20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connexion web universelle', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('iOS ↔ Android, Android ↔ Android et iOS ↔ iOS via une signalisation WebSocket sécurisée. Aucun accès Bluetooth n’est requis dans le navigateur.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _internetService.setEnabled(true),
                      icon: const Icon(Icons.link),
                      label: const Text('Activer la connexion web'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _webPeerController,
                      decoration: const InputDecoration(labelText: 'Identifiant UpChat du destinataire', border: OutlineInputBorder()),
                      autocorrect: false,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                      onSubmitted: (_) => _sendWebMessage(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: _sendWebMessage, icon: const Icon(Icons.send), label: const Text('Envoyer via WebSocket')),
                  ],
                ),
              ),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 20), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 24),
          Text('${_devices.length} appareil${_devices.length == 1 ? '' : 's'} trouvé${_devices.length == 1 ? '' : 's'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (_devices.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [Icon(Icons.devices_other_outlined, size: 42, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 10), const Text('Aucun appareil détecté'), const SizedBox(height: 6), const Text('Ouvre cette page sur les deux téléphones et accepte les autorisations.', textAlign: TextAlign.center)])))
          else ..._devices.map((device) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.smartphone)), title: Text(device.deviceName.isEmpty ? 'Appareil sans nom' : device.deviceName), subtitle: Text(_stateLabel(device.state)), onTap: device.state == SessionState.connected ? () => setState(() => _selectedDeviceId = device.deviceId) : null, trailing: device.state == SessionState.connected ? Icon(_selectedDeviceId == device.deviceId ? Icons.radio_button_checked : Icons.check_circle, color: Colors.green) : FilledButton(onPressed: () => _nearbyService.invitePeer(deviceID: device.deviceId, deviceName: device.deviceName), child: const Text('Connecter'))))),
          if (!isWeb && _selectedDeviceId != null)
            Card(
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Échange pair-à-pair', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(controller: _messageController, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: 'Message à envoyer', suffixIcon: IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)))),
                  if (_lastMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_lastMessage!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  String _stateLabel(SessionState state) => switch (state) {
        SessionState.connected => 'Connecté',
        SessionState.connecting => 'Connexion en cours…',
        SessionState.notConnected => 'Disponible',
      };
}
