import 'package:flutter/material.dart';
import '../../data/services/media_service.dart';

/// Aide UI pour choisir un média
class MediaHelper {
  static Future<void> showMediaPicker({
    required BuildContext context,
    required Function(String path, String type) onPicked,
  }) async {
    final media = MediaService();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await media.pickImage(fromCamera: false);
                  if (file != null) onPicked(file.path, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Caméra'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await media.pickImage(fromCamera: true);
                  if (file != null) onPicked(file.path, 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Vidéo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await media.pickVideo(fromCamera: false);
                  if (file != null) onPicked(file.path, 'video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Annuler'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}
