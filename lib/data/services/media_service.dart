import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Service de gestion des médias (images, fichiers)
/// Compression basique des images pour rester léger en P2P
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Choisir une image depuis la galerie ou la caméra
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70, // compression auto
      );
      if (picked == null) return null;

      // Copie dans le dossier de l'app pour persistance
      return await _saveToAppDir(File(picked.path), 'images');
    } catch (e) {
      debugPrint('Erreur pickImage: $e');
      return null;
    }
  }

  /// Choisir une vidéo
  Future<File?> pickVideo({bool fromCamera = false}) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return null;
      return await _saveToAppDir(File(picked.path), 'videos');
    } catch (e) {
      debugPrint('Erreur pickVideo: $e');
      return null;
    }
  }

  /// Sauvegarde un fichier dans le dossier permanent de l'app
  Future<File> _saveToAppDir(File source, String subfolder) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'upchat_media', subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final ext = p.extension(source.path);
    final filename = '${_uuid.v4()}$ext';
    final target = File(p.join(targetDir.path, filename));
    return await source.copy(target.path);
  }

  /// Taille d'un fichier en Ko
  Future<int> fileSizeKb(File file) async {
    final bytes = await file.length();
    return (bytes / 1024).round();
  }
}
