import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Avatar réutilisable : affiche la photo de profil si disponible, sinon l'initiale
class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? photoPath;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Sur le web, les chemins fichiers locaux ne marchent pas
    if (kIsWeb || photoPath == null || photoPath!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.7,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final file = File(photoPath!);

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: ClipOval(
        child: Image.file(
          file,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: AppColors.primary,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.7,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: AppColors.primary,
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.7,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
