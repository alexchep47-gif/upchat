import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Avatar réutilisable : affiche la photo locale ou la data URI Web.
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

  Widget _fallback(String initial) {
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

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final path = photoPath;
    if (path == null || path.isEmpty) return _fallback(initial);

    if (path.startsWith('data:image/')) {
      try {
        final encoded = path.substring(path.indexOf(',') + 1);
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primary,
          child: ClipOval(
            child: Image.memory(
              base64Decode(encoded),
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(initial),
            ),
          ),
        );
      } catch (_) {
        return _fallback(initial);
      }
    }

    if (kIsWeb) return _fallback(initial);
    final file = File(path);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: ClipOval(
        child: Image.file(
          file,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(initial),
        ),
      ),
    );
  }
}
