import 'package:flutter/foundation.dart';

/// Service d'enregistrement des notes vocales
/// (implémentation complète reportée — package record incompatible avec le build CI actuel)
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Démarre l'enregistrement (stub)
  Future<bool> startRecording() async {
    if (kIsWeb) return false;
    debugPrint('VoiceService: enregistrement non disponible pour le moment');
    return false;
  }

  /// Arrête l'enregistrement (stub)
  Future<String?> stopRecording() async {
    _isRecording = false;
    return null;
  }

  Future<void> cancelRecording() async {
    _isRecording = false;
  }

  Future<void> dispose() async {}
}
