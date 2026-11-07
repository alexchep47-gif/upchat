import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/internet_service.dart';

/// Gère le profil de l'utilisateur local
class ProfileProvider extends ChangeNotifier {
  String _name = 'Utilisateur';
  String? _bio;
  String? _photoPath;
  String? _phoneNumber;

  String get name => _name;
  String? get bio => _bio;
  String? get photoPath => _photoPath;
  String? get phoneNumber => _phoneNumber;
  String get userId => StorageService.userId;

  ProfileProvider() {
    _load();
  }

  void _load() {
    _name = StorageService.userName;
    _bio = StorageService.userBio;
    _phoneNumber = StorageService.userPhone;
    final path = StorageService.userPhotoPath;
    if (path != null && !kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        _photoPath = path;
      } else {
        _photoPath = null;
        StorageService.setUserPhotoPath(null);
      }
    } else {
      _photoPath = path;
    }
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    _name = newName.trim().isEmpty ? 'Utilisateur' : newName.trim();
    await StorageService.setUserName(_name);
    await InternetService().reregister(force: true);
    notifyListeners();
  }

  Future<void> updateBio(String? newBio) async {
    _bio = newBio?.trim();
    await StorageService.setUserBio(_bio);
    notifyListeners();
  }

  Future<void> updatePhone(String? phone) async {
    final normalized =
        phone == null || phone.trim().isEmpty
            ? null
            : StorageService.normalizePhone(phone);
    _phoneNumber = normalized;
    await StorageService.setUserPhone(normalized);
    // Publie le numéro sur le relais même si le toggle internet était OFF
    try {
      await InternetService().reregister(force: true);
    } catch (e) {
      debugPrint('ProfileProvider: publication numéro échouée: $e');
      // On garde le numéro local ; l'utilisateur pourra réessayer avec internet
    }
    notifyListeners();
  }

  Future<void> updatePhoto(String? path) async {
    if (path != null && !kIsWeb) {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('ProfileProvider: fichier photo introuvable: $path');
        return;
      }
    }
    _photoPath = path;
    await StorageService.setUserPhotoPath(path);
    notifyListeners();
  }
}
