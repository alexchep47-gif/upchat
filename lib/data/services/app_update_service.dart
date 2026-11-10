import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.releaseUrl,
    this.androidUrl,
    this.iosUrl,
    this.notes = '',
  });

  final String latestVersion;
  final String minimumVersion;
  final String releaseUrl;
  final String? androidUrl;
  final String? iosUrl;
  final String notes;

  bool get isUpdateAvailable =>
      AppUpdateService.compareVersions(latestVersion, AppConstants.appVersion) > 0;

  bool get isRequired =>
      AppUpdateService.compareVersions(AppConstants.appVersion, minimumVersion) < 0;

  String? get platformUrl {
    if (kIsWeb) return releaseUrl;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidUrl ?? releaseUrl;
      case TargetPlatform.iOS:
        return iosUrl ?? releaseUrl;
      default:
        return releaseUrl;
    }
  }

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final latest = json['latestVersion'];
    final minimum = json['minimumVersion'];
    final releaseUrl = json['releaseUrl'];
    if (latest is! String || minimum is! String || releaseUrl is! String) {
      throw const FormatException('Manifest de mise à jour incomplet');
    }
    return AppUpdateInfo(
      latestVersion: latest,
      minimumVersion: minimum,
      releaseUrl: releaseUrl,
      androidUrl: json['androidUrl'] as String?,
      iosUrl: json['iosUrl'] as String?,
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Vérification légère et facultative d’un manifeste public.
/// Le téléchargement et l’installation restent sous le contrôle de l’utilisateur.
class AppUpdateService {
  static Future<AppUpdateInfo?> check({http.Client? client}) async {
    final manifestUrl = AppConstants.updateManifestUrl.trim();
    if (manifestUrl.isEmpty) return null;

    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.scheme != 'https') return null;

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final info = AppUpdateInfo.fromJson(Map<String, dynamic>.from(data));
      return info.isUpdateAvailable ? info : null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<bool> open(AppUpdateInfo info) async {
    final url = info.platformUrl;
    if (url == null) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static int compareVersions(String left, String right) {
    List<int> parts(String value) => value
        .split(RegExp(r'[.+-]'))
        .take(3)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final a = parts(left);
    final b = parts(right);
    for (var i = 0; i < 3; i++) {
      final comparison = (a.length > i ? a[i] : 0).compareTo(b.length > i ? b[i] : 0);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
