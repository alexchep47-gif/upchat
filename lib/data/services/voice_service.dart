import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Service d'enregistrement et de gestion des notes vocales
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    if (kIsWeb) return false;

    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final voiceDir = Directory(p.join(dir.path, 'upchat_media', 'voice'));
        if (!await voiceDir.exists()) await voiceDir.create(recursive: true);

        _currentPath = p.join(voiceDir.path, '${_uuid.v4()}.m4a');

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentPath!,
        );

        _isRecording = true;
        return true;
      }
    } catch (e) {
      debugPrint('Erreur startRecording: $e');
    }
    return false;
  }

  /// Arrête l'enregistrement et retourne le chemin du fichier
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _currentPath = null;
      return path;
    } catch (e) {
      debugPrint('Erreur stopRecording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Annule l'enregistrement en cours
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.stop();
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    _isRecording = false;
    _currentPath = null;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
