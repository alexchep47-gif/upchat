import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';

/// Gère le profil de l'utilisateur local
class ProfileProvider extends ChangeNotifier {
  String _name = 'Utilisateur';
  String? _bio;
  String? _photoPath;

  String get name => _name;
  String? get bio => _bio;
  String? get photoPath => _photoPath;
  String get userId => StorageService.userId;

  ProfileProvider() {
    _load();
  }

  void _load() {
    _name = StorageService.userName;
    _bio = StorageService.userBio;
    _photoPath = StorageService.userPhotoPath;
    notifyListeners();
  }

  Future<void> updateName(String newName) async {
    _name = newName.trim().isEmpty ? 'Utilisateur' : newName.trim();
    await StorageService.setUserName(_name);
    notifyListeners();
  }

  Future<void> updateBio(String? newBio) async {
    _bio = newBio?.trim();
    await StorageService.setUserBio(_bio);
    notifyListeners();
  }

  Future<void> updatePhoto(String? path) async {
    _photoPath = path;
    await StorageService.setUserPhotoPath(path);
    notifyListeners();
  }
}
