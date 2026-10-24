import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../data/services/contact_directory_service.dart';
import '../data/models/user_model.dart';

/// Gère le profil de l'utilisateur local
class ProfileProvider extends ChangeNotifier {
  String _name = 'Utilisateur';
  String? _phoneNumber;
  String? _bio;
  String? _photoPath;

  String get name => _name;
  String? get phoneNumber => _phoneNumber;
  String? get bio => _bio;
  String? get photoPath => _photoPath;
  String get userId => StorageService.userId;

  ProfileProvider() {
    _load();
  }

  void _load() {
    _name = StorageService.userName;
    _phoneNumber = StorageService.userPhone;
    _bio = StorageService.userBio;
    final path = StorageService.userPhotoPath;
    // Vérifie que le fichier existe encore (Android)
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
    await _syncDirectoryRecord();
    notifyListeners();
  }

  Future<void> updatePhone(String? newPhone) async {
    final normalized = newPhone == null ? null : UserModel.normalizePhone(newPhone);
    _phoneNumber = normalized == '' ? null : normalized;
    await StorageService.setUserPhone(_phoneNumber);
    await _syncDirectoryRecord();
    notifyListeners();
  }

  Future<void> _syncDirectoryRecord() async {
    final user = UserModel(
      id: userId,
      name: _name,
      phoneNumber: _phoneNumber,
      bio: _bio,
      photoPath: _photoPath,
    );
    await ContactDirectoryService.instance.upsert(user);
  }

  Future<void> updateBio(String? newBio) async {
    _bio = newBio?.trim();
    await StorageService.setUserBio(_bio);
    await _syncDirectoryRecord();
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
    await _syncDirectoryRecord();
    notifyListeners();
  }
}
