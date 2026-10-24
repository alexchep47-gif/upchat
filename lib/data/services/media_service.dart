import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Service de gestion des médias (images, vidéos, fichiers).
class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;
  MediaService._internal();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Retourne un chemin local sur mobile ou une data URI persistante sur Web.
  Future<String?> pickImage({bool fromCamera = false}) async {
    try {
      final picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (picked == null) return null;
      return _persistPickedFile(picked, 'images', 'image');
    } catch (e) {
      debugPrint('Erreur pickImage: $e');
      return null;
    }
  }

  /// Retourne un chemin local sur mobile ou une data URI persistante sur Web.
  Future<String?> pickVideo({bool fromCamera = false}) async {
    try {
      final picked = await _picker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return null;
      return _persistPickedFile(picked, 'videos', 'video');
    } catch (e) {
      debugPrint('Erreur pickVideo: $e');
      return null;
    }
  }

  Future<String> _persistPickedFile(
    XFile picked,
    String subfolder,
    String kind,
  ) async {
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final extension = p.extension(picked.name).toLowerCase();
      final mime = kind == 'image'
          ? _imageMime(extension)
          : _videoMime(extension);
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    final source = File(picked.path);
    final saved = await _saveToAppDir(source, subfolder);
    return saved.path;
  }

  String _imageMime(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  String _videoMime(String extension) {
    switch (extension) {
      case '.webm':
        return 'video/webm';
      case '.mov':
        return 'video/quicktime';
      default:
        return 'video/mp4';
    }
  }

  Future<File> _saveToAppDir(File source, String subfolder) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'upchat_media', subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final ext = p.extension(source.path);
    final filename = '${_uuid.v4()}$ext';
    final target = File(p.join(targetDir.path, filename));
    return source.copy(target.path);
  }

  Future<int> fileSizeKb(File file) async {
    final bytes = await file.length();
    return (bytes / 1024).round();
  }
}
