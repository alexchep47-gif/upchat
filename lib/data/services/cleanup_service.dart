import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import 'storage_service.dart';

/// Nettoyage automatique : stories expirées + médias anciens
class CleanupService {
  static final CleanupService _instance = CleanupService._internal();
  factory CleanupService() => _instance;
  CleanupService._internal();

  /// Durée de conservation des médias (par défaut 7 jours)
  static const Duration mediaRetention = Duration(days: 7);

  /// Lance un nettoyage complet
  Future<CleanupReport> run() async {
    final report = CleanupReport();

    // 1. Stories expirées
    report.storiesDeleted = await _cleanExpiredStories();

    // 2. Médias trop vieux
    report.mediaDeleted = await _cleanOldMedia();

    // 3. Messages de relais mesh orphelins
    report.relayCleared = await _cleanOldRelayMessages();

    debugPrint(
      'Cleanup: ${report.storiesDeleted} stories, '
      '${report.mediaDeleted} médias, '
      '${report.relayCleared} relais nettoyés',
    );

    return report;
  }

  Future<int> _cleanExpiredStories() async {
    int count = 0;
    final keysToDelete = <dynamic>[];

    for (final key in StorageService.stories.keys) {
      final map = StorageService.stories.get(key);
      if (map is Map) {
        final expiresAt = map['expiresAt'] as String?;
        if (expiresAt != null) {
          final exp = DateTime.tryParse(expiresAt);
          if (exp != null && DateTime.now().isAfter(exp)) {
            keysToDelete.add(key);
            // Supprime aussi le fichier média associé
            final mediaPath = map['mediaPath'] as String?;
            if (mediaPath != null && !kIsWeb) {
              try {
                final f = File(mediaPath);
                if (await f.exists()) await f.delete();
              } catch (_) {}
            }
          }
        }
      }
    }

    for (final key in keysToDelete) {
      await StorageService.stories.delete(key);
      count++;
    }
    return count;
  }

  Future<int> _cleanOldMedia() async {
    if (kIsWeb) return 0;

    int count = 0;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mediaRoot = Directory(p.join(dir.path, 'upchat_media'));
      if (!await mediaRoot.exists()) return 0;

      final cutoff = DateTime.now().subtract(mediaRetention);

      await for (final entity in mediaRoot.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur cleanOldMedia: $e');
    }
    return count;
  }

  Future<int> _cleanOldRelayMessages() async {
    int count = 0;
    final keysToDelete = <dynamic>[];
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));

    for (final key in StorageService.messages.keys) {
      if (key.toString().startsWith('relay_')) {
        final map = StorageService.messages.get(key);
        if (map is Map) {
          final createdAt = map['createdAt'] as String?;
          if (createdAt != null) {
            final dt = DateTime.tryParse(createdAt);
            if (dt != null && dt.isBefore(cutoff)) {
              keysToDelete.add(key);
            }
          } else {
            keysToDelete.add(key);
          }
        }
      }
    }

    for (final key in keysToDelete) {
      await StorageService.messages.delete(key);
      count++;
    }
    return count;
  }
}

class CleanupReport {
  int storiesDeleted = 0;
  int mediaDeleted = 0;
  int relayCleared = 0;

  int get total => storiesDeleted + mediaDeleted + relayCleared;
}
